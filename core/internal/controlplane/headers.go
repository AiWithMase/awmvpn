package controlplane

import (
	"fmt"
	"net/http"
	"runtime"
	"strings"
	"sync/atomic"
)

// defaultFirefoxMajor is the Firefox release when this was written; the
// current one replaces it once Mozilla's product details answer
// (SetFirefoxVersion), so the User-Agent never falls far behind.
const defaultFirefoxMajor = "158"

var firefoxMajor atomic.Value // string

// SetFirefoxVersion makes FirefoxUserAgent name the Firefox release
// version ("158.0.1", product details' LATEST_FIREFOX_VERSION); anything
// that does not start with a number is ignored.
func SetFirefoxVersion(version string) {
	major, _, _ := strings.Cut(strings.TrimSpace(version), ".")
	if major == "" || strings.Trim(major, "0123456789") != "" {
		return
	}
	firefoxMajor.Store(major)
}

// FirefoxUserAgent is the User-Agent of desktop Firefox on this system,
// which Firefox's built-in VPN sends with every request it makes: to
// Guardian, Firefox Accounts, Remote Settings, and the proxy's CONNECT.
// The built-in VPN is a desktop feature, so Android gets the most common
// desktop's: Windows.
func FirefoxUserAgent() string {
	major, _ := firefoxMajor.Load().(string)
	if major == "" {
		major = defaultFirefoxMajor
	}
	return fmt.Sprintf("Mozilla/5.0 (%s; rv:%s.0) Gecko/20100101 Firefox/%s.0", firefoxPlatform(runtime.GOOS, runtime.GOARCH), major, major)
}

// firefoxPlatform is the system part of Firefox's User-Agent: Firefox
// reports Windows 11 as NT 10.0 and every Mac as Intel, 10.15.
func firefoxPlatform(goos, goarch string) string {
	switch goos {
	case "windows", "android":
		return "Windows NT 10.0; Win64; x64"
	case "darwin":
		return "Macintosh; Intel Mac OS X 10.15"
	}
	if goarch == "arm64" {
		return "X11; Linux aarch64"
	}
	return "X11; Linux x86_64"
}

// vpnClientVersion is the Mozilla VPN release the control plane expects to
// see in the User-Agent. Mozilla's client names its own version here, and
// mirrors of it (FoxyVPN) use this one.
const vpnClientVersion = "2.24.0"

// MozillaVPNUserAgent is the User-Agent Mozilla's control plane accepts.
//
// Mozilla changed the FxA control plane: the desktop Firefox User-Agent this
// program used is now refused on the account, Guardian, and Remote Settings
// APIs. Mozilla's own VPN client identifies itself as MozillaVPN/<version>
// (sys:<os> <version>), and so does FoxyVPN (Vauth/FoxyVPN v2.0.2), whose
// flow is known to work. The data plane (the proxy's CONNECT) keeps
// FirefoxUserAgent: that side still expects a browser.
func MozillaVPNUserAgent() string {
	return "MozillaVPN/" + vpnClientVersion + " (sys:" + vpnPlatform(runtime.GOOS) + ")"
}

// vpnPlatform is the system part of MozillaVPN's User-Agent
// (NetworkManager::osVersion in mozilla-vpn-client): product type and
// version where one is known.
func vpnPlatform(goos string) string {
	switch goos {
	case "windows":
		return "windows 10"
	case "darwin":
		return "macos 14"
	case "android":
		return "android 14"
	default:
		return "linux"
	}
}

// ApplyFirefoxHeaders sets the headers Mozilla's control plane expects:
// the Mozilla VPN client's User-Agent, "*/*", and an unencoded body. The
// last one keeps Go's transport from adding Accept-Encoding: gzip, which the
// control plane rejects.
func ApplyFirefoxHeaders(req *http.Request) {
	req.Header.Set("User-Agent", MozillaVPNUserAgent())
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Accept-Encoding", "identity")
}
