# Build stage
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w -extldflags=-static" \
    -o preview-router \
    .

# Final stage - distroless for security
FROM gcr.io/distroless/static-debian12:nonroot

# Copy the binary from builder
COPY --from=builder /app/preview-router /preview-router

# Use non-root user (65532 is nonroot user in distroless)
USER 65532:65532

# Expose port
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["/preview-router"]