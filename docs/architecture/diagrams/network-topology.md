# Network Topology with Istio Service Mesh

This diagram shows the network architecture of the Judge platform using Istio service mesh for traffic management, security, and observability.

```mermaid
graph TB
    subgraph Internet
        Users[External Users]
        CI[CI/CD Systems]
    end

    subgraph "AWS VPC"
        subgraph "AWS ALB"
            ALB[Application Load Balancer<br/>SSL Termination]
        end

        subgraph "EKS Cluster - judge namespace"
            subgraph "Istio System"
                Gateway[Istio Ingress Gateway<br/>istio-ingressgateway]
            end

            subgraph "Frontend Services"
                VS_Web[VirtualService<br/>judge.domain.com]
                VS_Login[VirtualService<br/>login.domain.com]
                VS_Archivista[VirtualService<br/>archivista.domain.com]

                JudgeWeb[judge-web<br/>:80]
                KratosUI[kratos-selfservice-ui<br/>:3000]
            end

            subgraph "API Services"
                Gateway_Svc[federation-gateway<br/>:4000]
                JudgeAPI[judge-api<br/>:8080]
                Archivista[archivista<br/>:8082]
            end

            subgraph "Auth Services"
                KratosPublic[kratos-public<br/>:80]
                KratosAdmin[kratos-admin<br/>:80]
            end

            subgraph "PKI Services"
                Fulcio[fulcio<br/>:5555]
                TSA[tsa<br/>:3000]
            end

            subgraph "Infrastructure Services"
                AIProxy[judge-ai-proxy<br/>:8080]
                Dapr[dapr-api<br/>:80]
            end
        end

        subgraph "AWS Managed Services"
            RDS[(RDS PostgreSQL<br/>Port 5432)]
            S3[S3 Buckets<br/>Artifacts & Attestations]
            SNS[SNS Topics<br/>Event Bus]
            SQS[SQS Queues<br/>Message Queue]
        end
    end

    %% External to ALB
    Users -->|HTTPS 443| ALB
    CI -->|HTTPS 443| ALB

    %% ALB to Istio Gateway
    ALB -->|HTTP 80| Gateway

    %% Gateway to VirtualServices
    Gateway -->|Host: judge.domain.com| VS_Web
    Gateway -->|Host: login.domain.com| VS_Login
    Gateway -->|Host: archivista.domain.com| VS_Archivista

    %% VirtualServices to Frontend
    VS_Web -->|mTLS| JudgeWeb
    VS_Login -->|mTLS| KratosUI

    %% Frontend to API Gateway
    JudgeWeb -->|mTLS| Gateway_Svc
    KratosUI -->|mTLS| KratosPublic

    %% API Gateway to Backend
    Gateway_Svc -->|mTLS| JudgeAPI
    Gateway_Svc -->|mTLS| Archivista
    Gateway_Svc -->|mTLS| AIProxy

    %% Backend to Auth
    JudgeAPI -->|mTLS| KratosAdmin
    JudgeWeb -->|mTLS| KratosPublic

    %% Backend to PKI
    JudgeAPI -->|mTLS| Fulcio
    JudgeAPI -->|mTLS| TSA

    %% Backend to Dapr
    JudgeAPI -.->|mTLS| Dapr
    Archivista -.->|mTLS| Dapr

    %% Services to AWS
    JudgeAPI -->|Private Link<br/>VPC Endpoint| RDS
    Archivista -->|Private Link| RDS
    KratosPublic -->|Private Link| RDS

    JudgeAPI -->|S3 API<br/>VPC Endpoint| S3
    Archivista -->|S3 API| S3

    Dapr -->|VPC Endpoint| SNS
    Dapr -->|VPC Endpoint| SQS

    %% Styling
    classDef external fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef istio fill:#e1f5ff,stroke:#01579b,stroke-width:3px
    classDef frontend fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef api fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef auth fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef pki fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef infra fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef aws fill:#fff9c4,stroke:#f57f17,stroke-width:2px

    class Users,CI external
    class ALB,Gateway,VS_Web,VS_Login,VS_Archivista istio
    class JudgeWeb,KratosUI frontend
    class Gateway_Svc,JudgeAPI,Archivista api
    class KratosPublic,KratosAdmin auth
    class Fulcio,TSA pki
    class AIProxy,Dapr infra
    class RDS,S3,SNS,SQS aws
```

## Network Layers

### Layer 1: External Access (ALB)
- **TLS Termination**: SSL certificates managed by ACM
- **Health Checks**: TCP health checks to Istio Gateway
- **Session Affinity**: Cookie-based for stateful apps
- **Timeout**: 2 minutes (ALB default)

### Layer 2: Istio Ingress Gateway
- **Namespace**: `istio-system`
- **Service Type**: LoadBalancer (targets ALB)
- **Ports**:
  - 80 (HTTP) - from ALB
  - 443 (HTTPS) - for direct access
  - 15021 (health check)
- **TLS Mode**: PASSTHROUGH (TLS handled by ALB)

### Layer 3: Istio VirtualServices
Intelligent routing based on HTTP Host headers:

```yaml
# judge-web VirtualService
- match:
  - uri:
      prefix: "/"
  route:
  - destination:
      host: judge-web
      port:
        number: 80

# kratos-selfservice-ui VirtualService
- match:
  - uri:
      prefix: "/"
  route:
  - destination:
      host: kratos-selfservice-ui-node
      port:
        number: 3000

# archivista VirtualService
- match:
  - uri:
      prefix: "/v1"
  route:
  - destination:
      host: archivista
      port:
        number: 8082
```

### Layer 4: Service-to-Service Communication
- **mTLS**: Automatic mutual TLS between all services
- **Protocol**: HTTP/2 with gRPC support
- **Load Balancing**: Round-robin by default
- **Circuit Breaking**: Enabled for resilience

## Security Features

### Istio mTLS
- **Mode**: STRICT (enforced for all traffic)
- **Certificate Rotation**: Automatic (24h TTL)
- **CA**: Istio CA (can be replaced with external CA)
- **Cipher Suites**: TLS 1.3 preferred

### Network Policies
```yaml
# Example: Restrict judge-api egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: judge-api-egress
spec:
  podSelector:
    matchLabels:
      app: judge-api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: kratos
  - to:
    - podSelector:
        matchLabels:
          app: fulcio
  - to:
    ports:
    - protocol: TCP
      port: 5432  # RDS
    - protocol: TCP
      port: 443   # S3/SNS/SQS
```

### VPC Endpoints
- **RDS**: PrivateLink for database access (no public IP)
- **S3**: Gateway VPC endpoint (free, no data transfer charges)
- **SNS/SQS**: Interface VPC endpoints for messaging

## Service Port Naming Convention

Istio requires protocol-specific port naming:

```yaml
ports:
- name: http-web        # HTTP traffic
  port: 80
- name: http-api        # HTTP API traffic
  port: 8080
- name: grpc-gateway    # gRPC traffic
  port: 4000
- name: http-admin      # HTTP admin interface
  port: 15000
```

Supported prefixes:
- `http-` or `http2-`: HTTP/1.1 or HTTP/2 traffic
- `grpc-`: gRPC traffic
- `tcp-`: Raw TCP traffic
- `tls-`: TLS-encrypted TCP traffic

## Observability

### Metrics (Prometheus)
- Request rate, latency, error rate
- Service-to-service traffic metrics
- mTLS certificate expiration

### Tracing (Jaeger/Zipkin)
- Distributed tracing across services
- Request flow visualization
- Performance bottleneck identification

### Logging (Fluentd/CloudWatch)
- Centralized log aggregation
- Access logs from Envoy proxies
- Application logs from containers

## Traffic Management Patterns

### Retry Policy
```yaml
retries:
  attempts: 3
  perTryTimeout: 2s
  retryOn: 5xx,reset,connect-failure
```

### Timeout Policy
```yaml
timeout: 10s
```

### Circuit Breaking
```yaml
connectionPool:
  http:
    http1MaxPendingRequests: 1024
    http2MaxRequests: 1024
    maxRequestsPerConnection: 1
  tcp:
    maxConnections: 1024
```

## Dapr + Istio Integration

Dapr sidecar and Istio Envoy proxy coexist:

```yaml
# Dapr port exclusions to prevent conflicts
annotations:
  traffic.sidecar.istio.io/excludeInboundPorts: "50001,9090"
  traffic.sidecar.istio.io/excludeOutboundPorts: "50001"
```

- **Dapr sidecar**: Handles application logic (pub/sub, state, workflows)
- **Istio Envoy**: Handles traffic management and security (mTLS, routing)

## DNS Resolution

### Internal DNS (CoreDNS)
```
<service>.<namespace>.svc.cluster.local
```

Examples:
- `judge-api.judge.svc.cluster.local:8080`
- `kratos-admin.judge.svc.cluster.local:80`
- `archivista.judge.svc.cluster.local:8082`

### External DNS (Route53)
```
<subdomain>.<domain>
```

Examples:
- `judge.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → judge-web
- `login.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → kratos-ui
- `archivista.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → archivista
