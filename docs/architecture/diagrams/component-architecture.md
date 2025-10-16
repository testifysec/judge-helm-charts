# Judge Platform Component Architecture

This diagram shows the high-level architecture of the Judge platform and how components interact.

```mermaid
graph TB
    %% External Access
    User[User/Client] -->|HTTPS| Istio[Istio Gateway]

    %% Frontend Layer
    Istio --> JudgeWeb[Judge Web UI]
    Istio --> KratosUI[Kratos Self-Service UI]

    %% Authentication Layer
    KratosUI --> Kratos[Kratos<br/>Identity & Auth]
    JudgeWeb --> Kratos
    Kratos --> Dex[Dex<br/>OIDC Provider]
    Dex --> OIDC[External OIDC<br/>GitHub/GitLab/Google]

    %% API Gateway Layer
    JudgeWeb --> Gateway[Federation Gateway<br/>GraphQL API]

    %% Core Services Layer
    Gateway --> JudgeAPI[Judge API<br/>Artifact Metadata]
    Gateway --> Archivista[Archivista<br/>Attestation Storage]
    Gateway --> AIProxy[Judge AI Proxy<br/>Policy Suggestions]

    %% PKI Services Layer
    JudgeAPI --> Fulcio[Fulcio<br/>Code Signing CA]
    JudgeAPI --> TSA[TSA<br/>RFC 3161 Timestamp]

    %% Key Management (TODO: Implement Tink+Vault)
    Fulcio -.->|TODO: Tink Keyset| Vault[HashiCorp Vault<br/>KMS]
    TSA -.->|TODO: Tink Keyset| Vault

    %% Infrastructure Layer
    JudgeAPI -.->|Workflows| Dapr[Dapr Runtime<br/>Messaging & State]
    Archivista -.->|Pub/Sub| Dapr

    %% Data Layer - Separate databases per service
    JudgeAPI -->|PostgreSQL| RDS_JudgeAPI[(RDS: judge_api<br/>Artifact Metadata)]
    Archivista -->|PostgreSQL| RDS_Archivista[(RDS: archivista<br/>Attestation Metadata)]
    Kratos -->|PostgreSQL| RDS_Kratos[(RDS: kratos<br/>Identity Data)]

    %% Storage Layer - Separate S3 buckets per service
    JudgeAPI -->|S3 API| S3_JudgeAPI[S3: demo-judge-judge<br/>Artifact Objects]
    Archivista -->|S3 API| S3_Archivista[S3: demo-judge-archivista<br/>Attestation Objects]

    %% Messaging Layer
    Dapr -->|SNS/SQS| Messaging[AWS SNS/SQS<br/>Event Bus]

    %% Styling
    classDef frontend fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef auth fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef core fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef pki fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef kms fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef infra fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef data fill:#fff9c4,stroke:#f57f17,stroke-width:2px

    class JudgeWeb,KratosUI frontend
    class Kratos,Dex,OIDC auth
    class Gateway,JudgeAPI,Archivista,AIProxy core
    class Fulcio,TSA pki
    class Vault kms
    class Dapr,Messaging infra
    class RDS_JudgeAPI,RDS_Archivista,RDS_Kratos,S3_JudgeAPI,S3_Archivista data
```

## Component Descriptions

### Frontend Layer
- **Judge Web UI**: React-based web interface for platform management
- **Kratos Self-Service UI**: Login, registration, and profile management

### Authentication Layer
- **Kratos**: Identity and user management (Ory Kratos)
- **Dex**: OpenID Connect provider for federated authentication
- **External OIDC**: Integration with GitHub, GitLab, Google, etc.

### Core Services Layer
- **Federation Gateway**: GraphQL API gateway orchestrating backend services
- **Judge API**: Core service for artifact metadata and policy management
- **Archivista**: Attestation storage and retrieval service
- **Judge AI Proxy**: AI/LLM integration for intelligent policy suggestions

### PKI Services Layer
- **Fulcio**: Code signing certificate authority (Sigstore) - **TODO**: Configure with Tink+Vault KMS for key management
- **TSA**: RFC 3161 timestamping authority for provenance - **TODO**: Configure with Tink+Vault KMS for key management
- **HashiCorp Vault**: KMS for encrypting Tink keysets (signing keys)

### Infrastructure Layer
- **Dapr Runtime**: Distributed application runtime for workflows and messaging
- **AWS SNS/SQS**: Event bus for asynchronous communication

### Data Layer
- **RDS Databases**: PostgreSQL 16 databases on shared RDS instance (`demo-judge-postgres`)
  - `judge_api`: Artifact metadata, compliance frameworks, and policy data
  - `archivista`: Attestation metadata and search indices
  - `kratos`: User identity, sessions, and authentication data
  - **CRITICAL**: Each service MUST have a separate database - using shared database causes Atlas migration conflicts
- **S3 Buckets**: Separate object storage per service (IRSA authentication)
  - `demo-judge-judge`: Judge API artifact storage (attestations, SBOMs, policies)
  - `demo-judge-archivista`: Archivista attestation objects and blobs

## Key Patterns

1. **Service Mesh**: Istio provides mTLS, traffic management, and observability
2. **Authentication Flow**: OIDC federation via Kratos and Dex
3. **API Gateway**: Federation Gateway provides unified GraphQL interface
4. **Event-Driven**: Dapr pub/sub for asynchronous workflows
5. **Data Isolation**: Each service has dedicated database and S3 bucket for security and schema independence
   - Prevents migration conflicts between services (Atlas schema versioning)
   - Enables independent service scaling and backup strategies
   - IRSA (IAM Roles for Service Accounts) provides per-service S3 permissions
6. **PKI Key Management** (TODO): Fulcio and TSA will use Google Tink with HashiCorp Vault KMS for secure key storage and signing operations
