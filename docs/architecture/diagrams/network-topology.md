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

            subgraph "Public VirtualServices"
                VS_Web[VirtualService<br/>judge.domain.com]
                VS_Login[VirtualService<br/>login.domain.com]
                VS_API[VirtualService<br/>api.domain.com]
                VS_Gateway[VirtualService<br/>gateway.domain.com]
                VS_Kratos[VirtualService<br/>kratos.domain.com]
                VS_Dex[VirtualService<br/>dex.domain.com]
                VS_Fulcio[VirtualService<br/>fulcio.domain.com]
                VS_TSA[VirtualService<br/>tsa.domain.com]
            end

            subgraph "Frontend Services"
                JudgeWeb[judge-web<br/>:8077]
                KratosUI[kratos-selfservice-ui<br/>:80]
            end

            subgraph "API Services"
                Gateway_Svc[federation-gateway<br/>:4000]
                JudgeAPI[judge-api<br/>:8080]
                Archivista[archivista<br/>:8082]
            end

            subgraph "Auth Services (Internal)"
                KratosPublic[kratos-public<br/>:80]
                KratosAdmin[kratos-admin<br/>:80]
            end

            subgraph "PKI Services"
                Fulcio[fulcio<br/>:80/gRPC]
                TSA[tsa<br/>:80]
            end

            subgraph "Infrastructure Services (Internal)"
                AIProxy[judge-ai-proxy<br/>:8080]
                Dapr[dapr-api<br/>:80]
            end
        end

        subgraph "AWS Managed Services"
            subgraph "RDS Instance: demo-judge-postgres"
                RDS_JudgeAPI[(judge_api DB<br/>Port 5432)]
                RDS_Archivista[(archivista DB<br/>Port 5432)]
                RDS_Kratos[(kratos DB<br/>Port 5432)]
            end
            S3_JudgeAPI[S3: demo-judge-judge<br/>Artifact Objects]
            S3_Archivista[S3: demo-judge-archivista<br/>Attestation Objects]
            SNS[SNS: demo-judge-archivista-attestations<br/>Event Bus]
            SQS[SQS: demo-judge-archivista-attestations<br/>Message Queue]
        end
    end

    %% External to ALB
    Users -->|HTTPS 443| ALB
    CI -->|HTTPS 443| ALB

    %% ALB to Istio Gateway
    ALB -->|HTTP 80| Gateway

    %% Gateway to Public VirtualServices
    Gateway -->|Host: judge.domain.com| VS_Web
    Gateway -->|Host: login.domain.com| VS_Login
    Gateway -->|Host: api.domain.com| VS_API
    Gateway -->|Host: gateway.domain.com| VS_Gateway
    Gateway -->|Host: kratos.domain.com| VS_Kratos
    Gateway -->|Host: dex.domain.com| VS_Dex
    Gateway -->|Host: fulcio.domain.com| VS_Fulcio
    Gateway -->|Host: tsa.domain.com| VS_TSA

    %% Public VirtualServices to Services
    VS_Web -->|mTLS| JudgeWeb
    VS_Login -->|mTLS| KratosUI
    VS_API -->|mTLS| JudgeAPI
    VS_Gateway -->|mTLS| Gateway_Svc
    VS_Kratos -->|mTLS| KratosPublic
    VS_Dex -->|mTLS| Dex
    VS_Fulcio -->|mTLS| Fulcio
    VS_TSA -->|mTLS| TSA

    %% Frontend Path-Based Routing
    JudgeWeb -->|/archivista/| Archivista
    JudgeWeb -->|/upload| Archivista
    JudgeWeb -->|/judge-api/| JudgeAPI
    JudgeWeb -->|/gateway/| Gateway_Svc
    JudgeWeb -->|/kratos/| KratosPublic
    JudgeWeb -->|/login/| KratosUI

    %% Frontend to Auth (internal)
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

    %% Services to AWS - Separate databases per service
    JudgeAPI -->|Private Link<br/>VPC Endpoint| RDS_JudgeAPI
    Archivista -->|Private Link| RDS_Archivista
    KratosPublic -->|Private Link| RDS_Kratos

    %% Services to S3 - Separate buckets per service (IRSA)
    JudgeAPI -->|S3 API<br/>VPC Endpoint<br/>IRSA| S3_JudgeAPI
    Archivista -->|S3 API<br/>IRSA| S3_Archivista

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
    class RDS_JudgeAPI,RDS_Archivista,RDS_Kratos,S3_JudgeAPI,S3_Archivista,SNS,SQS aws
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
Intelligent routing based on HTTP Host headers. Backend services are routed internally through path-based rules on judge-web VirtualService:

```yaml
# Judge Web VirtualService (public)
judge.domain.com:
  routes:
  - match:
      prefix: "/archivista/"
    destination:
      host: archivista
      port: 8082
  - match:
      prefix: "/upload"
    destination:
      host: archivista
      port: 8082
  - match:
      prefix: "/judge-api/"
    destination:
      host: judge-api
      port: 8080
  - match:
      prefix: "/"
    destination:
      host: judge-web
      port: 8077

# Judge API VirtualService (direct public route)
api.domain.com:
  destination:
    host: judge-api
    port: 8080

# Direct Public VirtualServices (one per service)
gateway.domain.com → federation-gateway:4000
kratos.domain.com → kratos-public:80
login.domain.com → kratos-selfservice-ui:80
dex.domain.com → dex:5556
fulcio.domain.com → fulcio:80
tsa.domain.com → tsa:80
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
  - Single RDS instance (`demo-judge-postgres`) with separate databases:
    - `judge_api` - Judge API artifact metadata (separate schema)
    - `archivista` - Attestation metadata (separate schema)
    - `kratos` - Identity and session data (separate schema)
  - **CRITICAL**: Each service requires a separate database to prevent Atlas migration conflicts
- **S3**: Gateway VPC endpoint (free, no data transfer charges)
  - Separate buckets per service with IRSA authentication:
    - `demo-judge-judge` - Judge API artifact storage
    - `demo-judge-archivista` - Archivista attestation objects
  - IAM roles: `demo-judge-judge-api` and `demo-judge-archivista`
- **SNS/SQS**: Interface VPC endpoints for messaging
  - Topic/Queue: `demo-judge-archivista-attestations`

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
  - `/archivista/` path routes internally to archivista (with auth/tenancy enforcement)
  - `/upload` endpoint routes to archivista with secure upload validation
- `login.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → kratos-ui
- `api.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → judge-api
- `gateway.testifysec-demo.xyz` → ALB → Istio Gateway → VirtualService → federation-gateway

**Note**: Archivista is NOT directly exposed at `archivista.{domain}`. Access is only via path-based routing through judge-web for security enforcement.
