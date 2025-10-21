#!/bin/bash
# Test the preview-router locally

set -e

echo "=== Building preview-router image ==="
cd ../app
docker build -t preview-router:test .

echo ""
echo "=== Starting test cluster (if using kind) ==="
echo "Make sure you have kind or minikube running"
echo ""

echo "=== Loading image into kind/minikube ==="
if command -v kind &> /dev/null; then
    kind load docker-image preview-router:test --name kind 2>/dev/null || true
elif command -v minikube &> /dev/null; then
    minikube image load preview-router:test 2>/dev/null || true
fi

echo ""
echo "=== Deploying test resources ==="
kubectl apply -f test-deployment.yaml

echo ""
echo "=== Waiting for pods to be ready ==="
kubectl wait --for=condition=ready pod -l app=preview-router -n judge --timeout=30s
kubectl wait --for=condition=ready pod -l app=preview-abc1234 -n judge --timeout=30s

echo ""
echo "=== Port forwarding preview-router ==="
echo "In another terminal, run:"
echo "  kubectl port-forward svc/preview-router -n judge 8080:8080"
echo ""
echo "Then test with:"
echo "  # Should proxy to the preview backend:"
echo "  curl -H 'Host: abc1234.preview.testifysec-demo.xyz' http://localhost:8080/"
echo ""
echo "  # Should redirect to fallback (bad host):"
echo "  curl -i -H 'Host: evil.com' http://localhost:8080/"
echo ""
echo "  # Test post-auth endpoint:"
echo "  curl -i 'http://localhost:8080/post-auth?next=https://abc1234.preview.testifysec-demo.xyz/'"
echo ""
echo "To clean up:"
echo "  kubectl delete -f test-deployment.yaml"