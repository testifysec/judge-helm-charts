// preview-router: Host-header based router for preview environments
package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"
)

// getEnv returns environment variable or default value
func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// SHA regex: 7-40 hex characters
var shaRegex = regexp.MustCompile(`^([a-f0-9]{7,40})\.preview\.`)

// Configuration from environment
var (
	previewNamespace   = getEnv("PREVIEW_NAMESPACE", "judge")
	serviceNamePattern = getEnv("SERVICE_NAME_PATTERN", "preview-%s-web")
	servicePort        = getEnv("SERVICE_PORT", "8077")
	fallbackURL        = getEnv("FALLBACK_URL", "https://judge.testifysec-demo.xyz/")
	domainSuffix       = getEnv("DOMAIN_SUFFIX", "preview.testifysec-demo.xyz")
)

func main() {
	// Set up routes
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/post-auth", handlePostAuth)
	http.HandleFunc("/", handlePreviewRoute)

	addr := ":8080"
	log.Printf("preview-router starting on %s", addr)
	log.Printf("config: namespace=%s pattern=%s port=%s domain=%s",
		previewNamespace, serviceNamePattern, servicePort, domainSuffix)

	// Server with timeouts
	server := &http.Server{
		Addr:              addr,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1 MB
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}

// handleHealth returns health status
func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

// handlePostAuth handles the post-authentication redirect
func handlePostAuth(w http.ResponseWriter, r *http.Request) {
	next := r.URL.Query().Get("next")
	if next == "" {
		log.Printf("post-auth: missing next parameter, redirecting to fallback")
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	// Parse and validate the next URL
	u, err := url.Parse(next)
	if err != nil {
		log.Printf("post-auth: invalid next URL: %q err=%v", next, err)
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	// Validate domain suffix
	if !strings.HasSuffix(u.Host, domainSuffix) {
		log.Printf("post-auth: invalid domain: %s (expected suffix %s)", u.Host, domainSuffix)
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	// Validate SHA format
	if !shaRegex.MatchString(u.Host) {
		log.Printf("post-auth: invalid SHA subdomain: %s", u.Host)
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	// Safe redirect to preview environment
	log.Printf("post-auth: redirect %s -> %s", r.RemoteAddr, u.String())
	http.Redirect(w, r, u.String(), http.StatusFound)
}

// handlePreviewRoute proxies requests to preview deployments based on Host header
func handlePreviewRoute(w http.ResponseWriter, r *http.Request) {
	host := r.Host

	// Validate host suffix
	if !strings.HasSuffix(host, domainSuffix) {
		log.Printf("route: invalid host suffix: %s (expected *.%s)", host, domainSuffix)
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	// Extract SHA from hostname
	matches := shaRegex.FindStringSubmatch(host)
	if len(matches) < 2 {
		log.Printf("route: invalid host format (no SHA): %s", host)
		http.Redirect(w, r, fallbackURL, http.StatusFound)
		return
	}

	sha := matches[1]
	serviceName := fmt.Sprintf(serviceNamePattern, sha)
	targetURL := fmt.Sprintf("http://%s.%s.svc.cluster.local:%s",
		serviceName, previewNamespace, servicePort)

	// Parse target URL
	target, err := url.Parse(targetURL)
	if err != nil {
		log.Printf("route: invalid target URL %s err=%v", targetURL, err)
		http.Error(w, "Internal routing error", http.StatusInternalServerError)
		return
	}

	// Create reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(target)

	// Custom director to preserve headers and add forwarding info
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)

		// Preserve original host for backend apps that need it
		req.Header.Set("X-Original-Host", host)

		// Set forwarded headers (trust Istio to set most of these)
		if req.Header.Get("X-Forwarded-Proto") == "" {
			req.Header.Set("X-Forwarded-Proto", "https")
		}
		if req.Header.Get("X-Forwarded-Host") == "" {
			req.Header.Set("X-Forwarded-Host", host)
		}

		// Log the proxy operation
		log.Printf("route: %s %s%s -> %s%s", r.Method, host, r.URL.Path, targetURL, req.URL.Path)
	}

	// Configure transport with timeouts
	proxy.Transport = &http.Transport{
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   10,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
	}

	// Error handler for backend failures
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("proxy error: host=%s sha=%s err=%v", host, sha, err)
		// Return 503 Service Unavailable instead of redirecting
		// This prevents redirect loops and makes errors debuggable
		http.Error(w, fmt.Sprintf("Preview environment '%s' is unavailable", sha),
			http.StatusServiceUnavailable)
	}

	// Serve the proxied request
	proxy.ServeHTTP(w, r)
}