# Preview Router

A lightweight HTTP router that enables authentication for preview environments by routing `*.preview.domain` traffic to dynamically created preview deployments.

## How It Works

1. **Host-based routing**: Routes requests from `<sha>.preview.testifysec-demo.xyz` to `preview-<sha>-web` services
2. **Post-auth redirect**: Handles `/post-auth` endpoint for Kratos authentication flow
3. **Fallback handling**: Redirects invalid requests to production site

## Configuration

Enable in your values:

```yaml
preview-router:
  enabled: true
  preview:
    domainSuffix: "preview.testifysec-demo.xyz"
    fallbackUrl: "https://judge.testifysec-demo.xyz/"
```

## Authentication Flow

1. User visits `https://abc1234.preview.testifysec-demo.xyz/`
2. Preview app checks Kratos session (not authenticated)
3. App redirects to: `https://kratos.testifysec-demo.xyz/self-service/login/browser?return_to=https://login.testifysec-demo.xyz/post-auth?next=<preview-url>`
4. User authenticates via GitHub OAuth
5. Kratos redirects to `/post-auth` endpoint
6. Router validates and redirects to preview environment
7. Session cookie works across all `*.testifysec-demo.xyz` subdomains

## Local Testing

```bash
cd test
chmod +x test-local.sh
./test-local.sh
```

## Building the Image

```bash
cd app
docker build -t <registry>/preview-router:v0.1.0 .
docker push <registry>/preview-router:v0.1.0
```

## Requirements

- Istio with wildcard VirtualService for `*.preview.domain`
- DNS wildcard record pointing to Istio ingress
- TLS certificate for `*.preview.domain`
- Kratos configured with `allowed_return_urls` including `/post-auth`

## Security

- Validates all redirect URLs against domain suffix
- Only allows redirects to `<sha>.preview.domain` pattern
- Returns 503 for missing preview services (no redirect loops)
- Runs as non-root user in distroless container