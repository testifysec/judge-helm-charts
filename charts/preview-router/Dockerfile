# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY app/go.mod app/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY app/*.go ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o preview-router .

# Final stage
FROM alpine:3.19

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1000 -S preview && \
    adduser -u 1000 -S preview -G preview

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/preview-router .

# Change ownership
RUN chown -R preview:preview /app

USER preview

EXPOSE 8080

ENTRYPOINT ["./preview-router"]