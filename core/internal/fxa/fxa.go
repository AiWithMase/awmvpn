// Package fxa implements the Firefox Accounts client: password login with
// HAWK-authenticated session calls, sign-in verification, OAuth token
// issuance and refresh, the Fastly anti-bot challenge that guards the
// account API, and the local OAuth token cache.
package fxa

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/aiwithmase/awmvpn/core/internal/controlplane"
)

const (
	fxaAuthServer  = "https://api.accounts.firefox.com/v1"
	fxaOAuthServer = "https://oauth.accounts.firefox.com/v1"
	firefoxClientID = "5882386c6d801776"
	oauthScope      = "profile https://identity.mozilla.com/apps/vpn"

	// maxChallengeAttempts bounds how many times an FxA call re-solves the
	// Fastly anti-bot challenge; with rotating-exit proxies a solved cookie
	// can be rejected when the API request leaves through another IP.
	maxChallengeAttempts = 5

	// fxaCallMinBudget is the minimum wall-clock budget an FxA call gets:
	// the caller's per-request timeout is often shorter than a full
	// challenge-solving round trip.
	fxaCallMinBudget = 90 * time.Second

	// verificationMethodEmail2FA tells FxA to deliver the sign-in
	// confirmation as a code emailed to the account instead of the
	// default confirmation link: the link redirects through
	// accounts.firefox.com, which warns about non-Firefox browsers and
	// cannot be followed from this CLI client.
	verificationMethodEmail2FA = "email-2fa"

	// fxaErrnoInvalidParameter is FxA's "Invalid parameter" errno; a
	// deployment that does not accept verificationMethod in the login
	// body answers with it, so we fall back to a plain login.
	fxaErrnoInvalidParameter = 107

	// fxaErrnoIncorrectEmailCase is FxA's "Incorrect email case" errno: the
	// email was typed in another letter case than the account's, which the
	// password's key stretching depends on. The error names the account's
	// own spelling.
	fxaErrnoIncorrectEmailCase = 120
)

type LoginResponse struct {
	SessionToken       string `json:"sessionToken"`
	UID                string `json:"uid"`
	Verified           bool   `json:"verified"`
	AuthAt             int64  `json:"authAt"`
	VerificationMethod string `json:"verificationMethod"`
	VerificationReason string `json:"verificationReason"`

	// Email is the email the sign-in succeeded with, in the account's own
	// letter case.
	Email string `json:"-"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	Scope        string `json:"scope"`
	TokenType    string `json:"token_type"`
}

// fxaAPIError carries a non-2xx FxA response so callers can branch on the
// API errno (e.g. invalid parameter) instead of parsing error strings.
type fxaAPIError struct {
	Status int
	Errno  int
	Body   string
	// Email is the account's email as FxA stores it, which sign-in errors
	// carry.
	Email string
}

func (e *fxaAPIError) Error() string {
	if e.Errno != 0 {
		return fmt.Sprintf("FxA error (HTTP %d, errno %d): %s", e.Status, e.Errno, e.Body)
	}
	return fmt.Sprintf("FxA request failed (HTTP %d): %s", e.Status, e.Body)
}

// ErrReauthRequired signals that FxA permanently rejected the stored
// credential (refresh token or session token), e.g. after the session was
// revoked server-side. Retrying cannot help; the user must sign in again.
var ErrReauthRequired = errors.New("Firefox Account sign-in required")

// Is lets errors.Is match ErrReauthRequired for credential rejections. FxA
// answers an invalid or revoked token with HTTP 400 (invalid_grant), 401,
// or 403; HTTP 429 and 5xx stay transient.
func (e *fxaAPIError) Is(target error) bool {
	if target != ErrReauthRequired {
		return false
	}
	switch e.Status {
	case http.StatusBadRequest, http.StatusUnauthorized, http.StatusForbidden:
		return e.Errno != fxaErrnoInvalidParameter
	}
	return false
}

func newFxaAPIError(status int, body []byte) *fxaAPIError {
	var parsed struct {
		Errno int    `json:"errno"`
		Email string `json:"email"`
	}
	_ = json.Unmarshal(body, &parsed)
	return &fxaAPIError{Status: status, Errno: parsed.Errno, Body: string(body), Email: parsed.Email}
}

// emailCaseError is the error of a sign-in repeated in the account's own
// letter case that still failed (for example blocked until an unblock
// code); it keeps that spelling for the next attempts.
type emailCaseError struct {
	email string
	err   error
}

func (e *emailCaseError) Error() string { return e.err.Error() }
func (e *emailCaseError) Unwrap() error { return e.err }

// fxaDo sends an FxA API request built by newRequest, transparently solving
// the Fastly anti-bot client challenge when the edge answers HTTP 406 (empty
// body, no FxA error payload). The request factory is invoked again after
// each successful solve because request bodies are single-use readers.
func fxaDo(ctx context.Context, newRequest func() (*http.Request, error)) (*http.Response, error) {
	ctx, cancel := contextWithMinDeadline(ctx, fxaCallMinBudget)
	defer cancel()

	for attempt := 1; attempt <= maxChallengeAttempts; attempt++ {
		req, err := newRequest()
		if err != nil {
			return nil, err
		}
		resp, err := controlplane.Do(req)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode != http.StatusNotAcceptable {
			return resp, nil
		}
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		resp.Body.Close()

		if err := solveFastlyChallenge(ctx); err != nil {
			return nil, fmt.Errorf("Fastly anti-bot challenge: %w", err)
		}
	}
	return nil, fmt.Errorf("Fastly anti-bot challenge still failing after %d attempts (HTTP 406)", maxChallengeAttempts)
}

// fxaLogin signs in. An email typed in another letter case than the
// account's is refused with the account's own spelling (errno 120); the
// sign-in is then repeated once with it, as Firefox does, naming the typed
// email as originalLoginEmail.
func fxaLogin(ctx context.Context, email, password, unblockCode string) (*LoginResponse, error) {
	resp, err := fxaLoginAs(ctx, email, "", password, unblockCode)
	var apiErr *fxaAPIError
	if errors.As(err, &apiErr) && apiErr.Errno == fxaErrnoIncorrectEmailCase && apiErr.Email != "" && apiErr.Email != email {
		resp, err = fxaLoginAs(ctx, apiErr.Email, email, password, unblockCode)
		if err != nil {
			return nil, &emailCaseError{email: apiErr.Email, err: err}
		}
	}
	return resp, err
}

// fxaLoginAs signs in as email; a deployment that does not accept the
// verification method is asked again without it.
func fxaLoginAs(ctx context.Context, email, originalEmail, password, unblockCode string) (*LoginResponse, error) {
	resp, err := fxaLoginAttempt(ctx, email, originalEmail, password, verificationMethodEmail2FA, unblockCode)
	var apiErr *fxaAPIError
	if errors.As(err, &apiErr) && apiErr.Errno == fxaErrnoInvalidParameter {
		resp, err = fxaLoginAttempt(ctx, email, originalEmail, password, "", unblockCode)
	}
	if err != nil {
		return nil, err
	}
	resp.Email = email
	return resp, nil
}

func fxaLoginAttempt(ctx context.Context, email, originalEmail, password, verificationMethod, unblockCode string) (*LoginResponse, error) {
	authPW, err := deriveAuthPW(email, password)
	if err != nil {
		return nil, fmt.Errorf("deriving authPW: %w", err)
	}

	body := map[string]string{
		"email":  email,
		"authPW": hex.EncodeToString(authPW),
	}
	if originalEmail != "" {
		body["originalLoginEmail"] = originalEmail
	}
	if verificationMethod != "" {
		body["verificationMethod"] = verificationMethod
	}
	if unblockCode != "" {
		body["unblockCode"] = unblockCode
	}
	bodyJSON, _ := json.Marshal(body)

	loginURL := fxaAuthServer + "/account/login"

	resp, err := fxaDo(ctx, func() (*http.Request, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, loginURL, strings.NewReader(string(bodyJSON)))
		if err != nil {
			return nil, fmt.Errorf("creating login request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return nil, fmt.Errorf("login request: %w", err)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, newFxaAPIError(resp.StatusCode, data)
	}

	var loginResp LoginResponse
	if err := json.Unmarshal(data, &loginResp); err != nil {
		return nil, fmt.Errorf("parsing login response: %w", err)
	}
	return &loginResp, nil
}

// fxaVerifySession submits the email confirmation code for an unverified
// session created by fxaLogin; FxA sends the code to the account email at
// login time.
func fxaVerifySession(ctx context.Context, sessionToken, code string) error {
	hawkID, hawkKey, err := deriveHawkCredentials(sessionToken, "sessionToken")
	if err != nil {
		return fmt.Errorf("deriving hawk credentials: %w", err)
	}

	body := map[string]string{"code": code}
	bodyJSON, _ := json.Marshal(body)
	verifyURL := fxaAuthServer + "/session/verify_code"

	resp, err := fxaDo(ctx, func() (*http.Request, error) {
		authHeader, err := hawkHeader("POST", verifyURL, hawkID, hawkKey, string(bodyJSON))
		if err != nil {
			return nil, fmt.Errorf("generating hawk header: %w", err)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, verifyURL, strings.NewReader(string(bodyJSON)))
		if err != nil {
			return nil, fmt.Errorf("creating verify code request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return fmt.Errorf("verify code request: %w", err)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return newFxaAPIError(resp.StatusCode, data)
	}
	return nil
}

// DestroySession ends a session token once its OAuth tokens are issued.
// Left alive, it stays in the account's connected services as an
// "unknown" session next to the device record; the program needs only the
// refresh token (and signs in again with the stored password when that
// stops working).
func DestroySession(ctx context.Context, sessionToken string) error {
	hawkID, hawkKey, err := deriveHawkCredentials(sessionToken, "sessionToken")
	if err != nil {
		return fmt.Errorf("deriving hawk credentials: %w", err)
	}
	const body = "{}"
	destroyURL := fxaAuthServer + "/session/destroy"
	resp, err := fxaDo(ctx, func() (*http.Request, error) {
		authHeader, err := hawkHeader("POST", destroyURL, hawkID, hawkKey, body)
		if err != nil {
			return nil, fmt.Errorf("generating hawk header: %w", err)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, destroyURL, strings.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("creating session destroy request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return fmt.Errorf("session destroy request: %w", err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return newFxaAPIError(resp.StatusCode, data)
	}
	return nil
}

// fxaOAuthToken mints an OAuth access/refresh token pair from a sign-in
// session token using the authorization-code flow with PKCE, as Mozilla's
// client and FoxyVPN v2.0.2 do. The older fxa-credentials grant this program
// used is no longer accepted on Mozilla's control plane.
//
// Step 1 asks the auth server for a one-time code (a HAWK-signed request);
// step 2 trades that code and its PKCE verifier for the tokens on the
// dedicated OAuth host. The state value ties the two steps together.
func fxaOAuthToken(ctx context.Context, sessionToken string) (*TokenResponse, error) {
	hawkID, hawkKey, err := deriveHawkCredentials(sessionToken, "sessionToken")
	if err != nil {
		return nil, fmt.Errorf("deriving hawk credentials: %w", err)
	}

	verifier, challenge, state, err := pkcePair()
	if err != nil {
		return nil, fmt.Errorf("generating PKCE values: %w", err)
	}

	authBody := map[string]interface{}{
		"client_id":             firefoxClientID,
		"response_type":         "code",
		"scope":                 oauthScope,
		"state":                 state,
		"access_type":           "offline",
		"code_challenge":        challenge,
		"code_challenge_method": "S256",
	}
	authJSON, _ := json.Marshal(authBody)

	authURL := fxaAuthServer + "/oauth/authorization"
	resp, err := fxaDo(ctx, func() (*http.Request, error) {
		authHeader, err := hawkHeader("POST", authURL, hawkID, hawkKey, string(authJSON))
		if err != nil {
			return nil, fmt.Errorf("generating hawk header: %w", err)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, authURL, strings.NewReader(string(authJSON)))
		if err != nil {
			return nil, fmt.Errorf("creating oauth authorization request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return nil, fmt.Errorf("oauth authorization request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, newFxaAPIError(resp.StatusCode, []byte(controlplane.ReadErrorBody(resp.Body)))
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading oauth authorization response: %w", err)
	}
	var issued struct {
		Code  string `json:"code"`
		State string `json:"state"`
	}
	if err := json.Unmarshal(data, &issued); err != nil {
		return nil, fmt.Errorf("parsing oauth authorization response: %w", err)
	}
	if issued.Code == "" || issued.State != state {
		return nil, fmt.Errorf("invalid oauth authorization response")
	}

	tokenBody := map[string]interface{}{
		"client_id":    firefoxClientID,
		"grant_type":   "authorization_code",
		"code":         issued.Code,
		"code_verifier": verifier,
	}
	tokenJSON, _ := json.Marshal(tokenBody)

	tokenURL := fxaOAuthServer + "/token"
	resp, err = fxaDo(ctx, func() (*http.Request, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, tokenURL, strings.NewReader(string(tokenJSON)))
		if err != nil {
			return nil, fmt.Errorf("creating oauth token request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return nil, fmt.Errorf("oauth token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, newFxaAPIError(resp.StatusCode, []byte(controlplane.ReadErrorBody(resp.Body)))
	}
	data, err = io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading token response: %w", err)
	}

	var tok TokenResponse
	if err := json.Unmarshal(data, &tok); err != nil {
		return nil, fmt.Errorf("parsing token response: %w", err)
	}
	if tok.AccessToken == "" {
		return nil, fmt.Errorf("oauth token response has no access token")
	}
	return &tok, nil
}

// pkcePair returns a PKCE verifier and its S256 challenge (both base64url
// without padding), plus a random state value.
func pkcePair() (verifier, challenge, state string, err error) {
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		return "", "", "", err
	}
	verifier = base64.RawURLEncoding.EncodeToString(secret)
	sum := sha256.Sum256([]byte(verifier))
	challenge = base64.RawURLEncoding.EncodeToString(sum[:])

	stateBytes := make([]byte, 16)
	if _, err = rand.Read(stateBytes); err != nil {
		return "", "", "", err
	}
	state = base64.RawURLEncoding.EncodeToString(stateBytes)
	return verifier, challenge, state, nil
}

// fxaRefreshToken attempts a refresh on the OAuth host first and falls back
// to the auth host's /oauth/token when that host is unreachable, blocks the
// request (406, one Fastly could not solve), is rate limited (429), or fails
// with a 5xx. A 400/401/403 means the refresh token itself was rejected, so
// the fallback would be rejected too and is skipped.
//
// This is the order FoxyVPN v2.0.2 and Mozilla's own client use
// (oauth.accounts.firefox.com/v1/token). Mozilla moved the refresh grant off
// the auth host; the old single auth-host URL is what stopped awmvpn's stored
// logins from renewing.
func fxaRefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error) {
	body := map[string]interface{}{
		"client_id":     firefoxClientID,
		"grant_type":    "refresh_token",
		"refresh_token": refreshToken,
		"scope":         oauthScope,
	}
	bodyJSON, _ := json.Marshal(body)

	endpoints := []string{
		fxaOAuthServer + "/token",
		fxaAuthServer + "/oauth/token",
	}

	var firstErr error
	for i, tokenURL := range endpoints {
		tok, err := refreshAt(ctx, tokenURL, string(bodyJSON))
		if err == nil {
			// The response may not include a new refresh token; keep the old.
			if tok.RefreshToken == "" {
				tok.RefreshToken = refreshToken
			}
			return tok, nil
		}
		if i == len(endpoints)-1 || !refreshFallsBack(err) {
			return nil, err
		}
		firstErr = err
	}
	return nil, firstErr
}

// refreshAt performs one refresh-grant POST to tokenURL.
func refreshAt(ctx context.Context, tokenURL, body string) (*TokenResponse, error) {
	resp, err := fxaDo(ctx, func() (*http.Request, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, tokenURL, strings.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("creating refresh request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		controlplane.ApplyFirefoxHeaders(req)
		return req, nil
	})
	if err != nil {
		return nil, fmt.Errorf("refresh request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, newFxaAPIError(resp.StatusCode, []byte(controlplane.ReadErrorBody(resp.Body)))
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading refresh response: %w", err)
	}

	var tok TokenResponse
	if err := json.Unmarshal(data, &tok); err != nil {
		return nil, fmt.Errorf("parsing refresh response: %w", err)
	}
	return &tok, nil
}

// refreshFallsBack reports whether a refresh failure on the OAuth host is
// one the auth host might answer instead of a rejection of the token.
func refreshFallsBack(err error) bool {
	var apiErr *fxaAPIError
	if errors.As(err, &apiErr) {
		switch apiErr.Status {
		case http.StatusNotAcceptable, http.StatusTooManyRequests,
			http.StatusInternalServerError, http.StatusBadGateway,
			http.StatusServiceUnavailable, http.StatusGatewayTimeout:
			return true
		}
		return false
	}
	// A transport failure or an unsolved Fastly challenge: the OAuth host
	// is unreachable or blocked, not the credential.
	return true
}

func Login(ctx context.Context, email, password string) (*LoginResponse, error) {
	return fxaLogin(ctx, email, password, "")
}

func VerifySession(ctx context.Context, sessionToken, code string) error {
	return fxaVerifySession(ctx, sessionToken, NormalizeCode(code))
}

func OAuthToken(ctx context.Context, sessionToken string) (*TokenResponse, error) {
	return fxaOAuthToken(ctx, sessionToken)
}

func RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error) {
	return fxaRefreshToken(ctx, refreshToken)
}
