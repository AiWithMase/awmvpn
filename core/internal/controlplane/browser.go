package controlplane

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"

	utls "github.com/refraction-networking/utls"
)

// browserClientHello is the TLS fingerprint the control plane presents.
// Mozilla's VPN client is built on Firefox's networking stack, and Fastly's
// anti-bot layer in front of Firefox Accounts compares the TLS ClientHello
// against the known clients: Go's own hello is answered with a bare HTTP 406
// before the request ever reaches Firefox Accounts, while a Firefox hello
// passes. The value is a utls preset name resolved at build time, so no
// network or configuration is involved.
var browserClientHello = utls.HelloFirefox_Auto

// NewTransport returns an HTTP/1.1 transport that speaks TLS with a Firefox
// ClientHello. Every control-plane request (Firefox Accounts, Guardian,
// Remote Settings, and the Fastly challenge solver) goes through it, so the
// requests look like the ones Mozilla's own client sends. dial is used for
// the TCP connection, which keeps the configured DNS servers (and, for the
// API relay, the relay's dialer) in charge.
func NewTransport(dial func(ctx context.Context, network, addr string) (net.Conn, error)) *http.Transport {
	return &http.Transport{
		Proxy:             http.ProxyFromEnvironment,
		DialContext:       dial,
		ForceAttemptHTTP2: false,
		TLSNextProto:      map[string]func(string, *tls.Conn) http.RoundTripper{},
		DialTLSContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			host, _, err := net.SplitHostPort(addr)
			if err != nil {
				return nil, err
			}
			raw, err := dial(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			conn, err := handshakeBrowserTLS(ctx, raw, host)
			if err != nil {
				raw.Close()
				return nil, err
			}
			return conn, nil
		},
	}
}

// handshakeBrowserTLS runs a TLS handshake with the browser ClientHello over
// raw. HTTP/1.1 is the only offered protocol: Go's HTTP/2 framing is as
// recognizable as its TLS hello, and the control plane does not need HTTP/2.
func handshakeBrowserTLS(ctx context.Context, raw net.Conn, host string) (net.Conn, error) {
	spec, err := utls.UTLSIdToSpec(browserClientHello)
	if err != nil {
		return nil, err
	}
	for _, ext := range spec.Extensions {
		if alpn, ok := ext.(*utls.ALPNExtension); ok {
			alpn.AlpnProtocols = []string{"http/1.1"}
		}
	}
	conn := utls.UClient(raw, &utls.Config{ServerName: host, MinVersion: tls.VersionTLS12}, utls.HelloCustom)
	if err := conn.ApplyPreset(&spec); err != nil {
		return nil, err
	}
	if err := conn.HandshakeContext(ctx); err != nil {
		return nil, err
	}
	return conn, nil
}
