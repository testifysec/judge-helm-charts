# Fulcio and TSA Trust Bootstrapping - Implementation Roadmap

**Status**: TODO - Implementation Required
**Priority**: High (Next Iteration Feature)
**Complexity**: Medium-High

## Overview

This document outlines the work required to bootstrap trust for Fulcio (code signing CA) and TSA (RFC 3161 timestamp authority) using HashiCorp Vault as the backend for key generation and storage.

## Current State

The Judge platform Helm charts include Fulcio and TSA services, but they currently use:
- **Fulcio**: Ephemeral or file-based CA keys (not production-ready)
- **TSA**: Ephemeral or file-based signing keys (not production-ready)
- **No Integration**: No Vault PKI integration for key material

## Target State

Production-ready PKI infrastructure with:
- **Vault PKI Backend**: Certificate authority managed by Vault
- **Self-Signed Root CA**: Stored in Vault, never exposed
- **Intermediate CAs**: For Fulcio and TSA (isolated key material)
- **Automated Key Rotation**: Vault-managed cert renewal
- **Trust Chain Distribution**: Root CA bundle published to known location

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ HashiCorp Vault                                             │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ PKI Secrets Engine: pki/                             │  │
│  │                                                       │  │
│  │  Root CA:                                            │  │
│  │    - Common Name: Judge Platform Root CA            │  │
│  │    - Validity: 10 years                             │  │
│  │    - Key Type: RSA 4096 or ECDSA P-384              │  │
│  │    - Usage: CA cert sign, CRL sign                  │  │
│  │    - Exported: NO (internal only)                   │  │
│  └──────────────────────────────────────────────────────┘  │
│         │                           │                       │
│         │ issues                    │ issues                │
│         ↓                           ↓                       │
│  ┌────────────────┐         ┌─────────────────┐           │
│  │ pki_fulcio/    │         │ pki_tsa/        │           │
│  │                │         │                 │           │
│  │ Intermediate   │         │ Intermediate    │           │
│  │ CA for Fulcio  │         │ CA for TSA      │           │
│  │                │         │                 │           │
│  │ Validity: 5yr  │         │ Validity: 5yr   │           │
│  └────────────────┘         └─────────────────┘           │
│         │                           │                       │
└─────────┼───────────────────────────┼───────────────────────┘
          │                           │
          │ Vault Agent               │ Vault Agent
          │ Sidecar                   │ Sidecar
          ↓                           ↓
   ┌─────────────┐            ┌──────────────┐
   │ Fulcio Pod  │            │ TSA Pod      │
   │             │            │              │
   │ - Mounts CA │            │ - Mounts CA  │
   │   cert      │            │   cert       │
   │ - Issues    │            │ - Issues     │
   │   ephemeral │            │   timestamps │
   │   certs     │            │              │
   └─────────────┘            └──────────────┘
```

## Implementation Tasks

### Phase 1: Vault PKI Setup (Terraform)

**TODO 1.1**: Create Vault root CA
```hcl
resource "vault_mount" "pki_root" {
  path                      = "pki"
  type                      = "pki"
  max_lease_ttl_seconds     = 315360000  # 10 years
}

resource "vault_pki_secret_backend_root_cert" "root" {
  backend               = vault_mount.pki_root.path
  type                  = "internal"  # Keep private key in Vault
  common_name           = "Judge Platform Root CA"
  ttl                   = "315360000"
  format                = "pem"
  private_key_format    = "der"
  key_type              = "rsa"
  key_bits              = 4096
  exclude_cn_from_sans  = true
  ou                    = "Judge Platform"
  organization          = "YOUR_ORGANIZATION"
}
```

**TODO 1.2**: Create Fulcio intermediate CA
```hcl
resource "vault_mount" "pki_fulcio" {
  path                  = "pki_fulcio"
  type                  = "pki"
  max_lease_ttl_seconds = 157680000  # 5 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "fulcio" {
  backend     = vault_mount.pki_fulcio.path
  type        = "internal"
  common_name = "Judge Platform Fulcio Intermediate CA"
  key_type    = "rsa"
  key_bits    = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "fulcio" {
  backend     = vault_mount.pki_root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.fulcio.csr
  common_name = "Judge Platform Fulcio Intermediate CA"
  ttl         = "157680000"
  format      = "pem_bundle"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "fulcio" {
  backend     = vault_mount.pki_fulcio.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.fulcio.certificate
}
```

**TODO 1.3**: Create TSA intermediate CA
```hcl
# Similar to Fulcio, create pki_tsa mount and intermediate cert
```

**TODO 1.4**: Configure PKI roles
```hcl
resource "vault_pki_secret_backend_role" "fulcio" {
  backend          = vault_mount.pki_fulcio.path
  name             = "fulcio-issuer"
  ttl              = 600  # 10 minutes (short-lived certs)
  max_ttl          = 3600
  allow_any_name   = true
  enforce_hostnames = false

  # Key usage for code signing
  key_usage = [
    "DigitalSignature",
    "KeyEncipherment"
  ]

  ext_key_usage = [
    "CodeSigning"
  ]
}

resource "vault_pki_secret_backend_role" "tsa" {
  backend          = vault_mount.pki_tsa.path
  name             = "tsa-signer"
  ttl              = 86400  # 24 hours
  max_ttl          = 604800  # 7 days
  allow_any_name   = false
  allowed_domains  = ["tsa.judge.svc.cluster.local"]

  # Key usage for timestamping
  key_usage = [
    "DigitalSignature"
  ]

  ext_key_usage = [
    "TimeStamping"
  ]
}
```

**TODO 1.5**: Create Vault policies for Fulcio and TSA
```hcl
resource "vault_policy" "fulcio" {
  name = "fulcio"

  policy = <<EOT
# Read Fulcio intermediate CA cert
path "pki_fulcio/cert/ca" {
  capabilities = ["read"]
}

# Issue certificates
path "pki_fulcio/issue/fulcio-issuer" {
  capabilities = ["create", "update"]
}

# Read issuer configuration
path "pki_fulcio/config/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "tsa" {
  name = "tsa"

  policy = <<EOT
# Read TSA intermediate CA cert
path "pki_tsa/cert/ca" {
  capabilities = ["read"]
}

# Issue certificates
path "pki_tsa/issue/tsa-signer" {
  capabilities = ["create", "update"]
}

# Read issuer configuration
path "pki_tsa/config/*" {
  capabilities = ["read"]
}
EOT
}
```

**TODO 1.6**: Update Kubernetes auth roles to include PKI policies
```hcl
resource "vault_kubernetes_auth_backend_role" "fulcio" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "fulcio"
  bound_service_account_names      = ["fulcio"]
  bound_service_account_namespaces = ["judge"]
  token_policies                   = [
    vault_policy.fulcio.name,
    # Add database policy if Fulcio needs DB access
  ]
  token_ttl                        = 86400
}
```

### Phase 2: Helm Chart Updates

**TODO 2.1**: Add Vault Agent sidecar to Fulcio deployment

Update `charts/fulcio/templates/deployment.yaml`:
```yaml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "fulcio"
        vault.hashicorp.com/agent-inject-secret-ca-cert: "pki_fulcio/cert/ca"
        vault.hashicorp.com/agent-inject-template-ca-cert: |
          {{- with secret "pki_fulcio/cert/ca" -}}
          {{ .Data.certificate }}
          {{- end }}
        vault.hashicorp.com/agent-inject-secret-ca-chain: "pki_fulcio/cert/ca_chain"
        vault.hashicorp.com/agent-inject-template-ca-chain: |
          {{- with secret "pki_fulcio/cert/ca_chain" -}}
          {{ .Data.ca_chain }}
          {{- end }}
```

**TODO 2.2**: Configure Fulcio to use Vault PKI backend

Add configuration in `charts/fulcio/values.yaml`:
```yaml
fulcio:
  config:
    OIDCIssuers:
      https://dex.judge.svc.cluster.local:
        IssuerURL: https://dex.judge.svc.cluster.local
        ClientID: fulcio
        Type: email

    # Vault PKI configuration
    CAConfig:
      Type: vaultpki
      VaultPKI:
        VaultAddr: https://vault.example.com
        VaultPath: pki_fulcio
        VaultRole: fulcio-issuer
        # Auth via Vault Agent (sidecar provides token)
        VaultTokenPath: /vault/secrets/.vault-token
```

**TODO 2.3**: Add Vault Agent sidecar to TSA deployment

Similar to Fulcio, update `charts/tsa/templates/deployment.yaml` with Vault Agent annotations.

**TODO 2.4**: Configure TSA to use Vault PKI backend

Update `charts/tsa/values.yaml`:
```yaml
tsa:
  config:
    # Vault PKI configuration
    CertChain:
      Type: vaultpki
      VaultPKI:
        VaultAddr: https://vault.example.com
        VaultPath: pki_tsa
        VaultRole: tsa-signer
        VaultTokenPath: /vault/secrets/.vault-token
```

### Phase 3: Trust Chain Distribution

**TODO 3.1**: Publish root CA bundle

Create Kubernetes ConfigMap with root CA:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: judge-root-ca-bundle
  namespace: judge
data:
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    # Root CA certificate from Vault
    -----END CERTIFICATE-----
```

**TODO 3.2**: Mount root CA bundle in application pods

Update deployments to trust the root CA:
```yaml
volumeMounts:
- name: ca-bundle
  mountPath: /etc/ssl/certs/judge-root-ca.crt
  subPath: ca-bundle.crt
  readOnly: true
```

**TODO 3.3**: Update OS trust store

Add init container to update system trust store:
```yaml
initContainers:
- name: update-ca-trust
  image: alpine:3.18
  command:
  - /bin/sh
  - -c
  - |
    cp /ca-bundle/ca-bundle.crt /usr/local/share/ca-certificates/
    update-ca-certificates
  volumeMounts:
  - name: ca-bundle
    mountPath: /ca-bundle
  - name: ca-certificates
    mountPath: /etc/ssl/certs
```

**TODO 3.4**: Document root CA installation for clients

Create `docs/deployment/trust-installation.md` with:
- How to download root CA bundle
- How to install in various OS trust stores (Linux, macOS, Windows)
- How to configure Docker/containerd to trust the CA
- How to configure language-specific trust stores (Go, Python, Node.js)

### Phase 4: Key Rotation Strategy

**TODO 4.1**: Document rotation procedures

Create `docs/deployment/pki-rotation.md`:
- Root CA rotation (10-year schedule)
- Intermediate CA rotation (5-year schedule)
- Automated rotation using Terraform
- Zero-downtime rotation procedure
- Rollback procedures

**TODO 4.2**: Implement rotation automation

Create Terraform module for CA rotation:
```hcl
# Rotation trigger based on certificate expiration
data "vault_pki_secret_backend_cert" "current" {
  backend = "pki_fulcio"
  role    = "fulcio-issuer"
}

# Alert when cert expires in < 90 days
resource "null_resource" "rotation_alert" {
  triggers = {
    expiration = data.vault_pki_secret_backend_cert.current.expiration
  }

  # Send alert to monitoring system
}
```

**TODO 4.3**: Test rotation procedures

- [ ] Rotate intermediate CA in staging environment
- [ ] Verify existing certs remain valid
- [ ] Verify new certs issued from new CA
- [ ] Test trust chain validation
- [ ] Document any issues encountered

### Phase 5: Security Hardening

**TODO 5.1**: Enable Vault audit logging

```hcl
resource "vault_audit" "file" {
  type = "file"

  options = {
    file_path = "/vault/logs/audit.log"
  }
}
```

**TODO 5.2**: Implement CA key backup

- Export root CA private key to secure offline location
- Use Vault's seal/unseal mechanism for disaster recovery
- Store recovery keys in multiple secure locations (split key strategy)

**TODO 5.3**: Configure CRL and OCSP

```hcl
resource "vault_pki_secret_backend_config_urls" "fulcio" {
  backend                 = vault_mount.pki_fulcio.path
  issuing_certificates    = ["https://vault.example.com/v1/pki_fulcio/ca"]
  crl_distribution_points = ["https://vault.example.com/v1/pki_fulcio/crl"]
}
```

**TODO 5.4**: Implement certificate revocation

- Define revocation policy (who can revoke, audit trail)
- Test CRL generation and distribution
- Verify clients check CRL/OCSP before trusting certs

## Testing Checklist

- [ ] Vault root CA successfully created
- [ ] Fulcio intermediate CA issued and chained to root
- [ ] TSA intermediate CA issued and chained to root
- [ ] Fulcio can issue short-lived code signing certificates
- [ ] TSA can issue RFC 3161 timestamps
- [ ] Trust chain validates from leaf → intermediate → root
- [ ] Vault Agent sidecar successfully authenticates
- [ ] Pods can mount CA certificates from Vault
- [ ] Certificate expiration alerts working
- [ ] Rotation procedures tested in staging
- [ ] Root CA bundle published and accessible
- [ ] Clients can verify signatures using root CA
- [ ] CRL generation and distribution working
- [ ] Audit logs capture all PKI operations

## Security Considerations

1. **Root CA Protection**:
   - NEVER export root CA private key
   - Use Vault's internal PKI backend (type: internal)
   - Enable Vault seal for encryption at rest

2. **Least Privilege**:
   - Fulcio policy only allows issuing from fulcio-issuer role
   - TSA policy only allows issuing from tsa-signer role
   - No pods should have access to root CA private key

3. **Key Material**:
   - Use RSA 4096 or ECDSA P-384 for production
   - Short TTLs for leaf certificates (10 min for code signing)
   - Intermediate CAs rotated every 5 years

4. **Trust Distribution**:
   - Publish root CA bundle to public, verifiable location
   - Consider using transparency logs (Rekor) for CA operations
   - Document trust chain for third-party verification

## Open Questions / Decisions Needed

1. **Key Algorithm**: RSA 4096 vs ECDSA P-384?
   - RSA: Better compatibility, larger keys
   - ECDSA: Smaller keys, faster operations, modern standard

2. **Root CA Validity**: 10 years vs 15 years?
   - Shorter is more secure but requires more frequent rotation
   - Industry standard moving toward shorter CA lifetimes

3. **Backup Strategy**: Where to store root CA recovery keys?
   - Hardware security module (HSM)?
   - Multiple encrypted offline locations?
   - Split key ceremony with multiple key holders?

4. **Public vs Private CA**: Should root CA be published to public CT logs?
   - Public: Better transparency, industry best practice
   - Private: More control, but less trust from third parties

## References

- [Vault PKI Secrets Engine](https://www.vaultproject.io/docs/secrets/pki)
- [Sigstore Fulcio](https://github.com/sigstore/fulcio)
- [RFC 3161 Timestamping](https://datatracker.ietf.org/doc/html/rfc3161)
- [X.509 Certificate Best Practices](https://cabforum.org/baseline-requirements-documents/)
- [Kubernetes CA Trust](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)

## Implementation Timeline

**Estimated Effort**: 2-3 weeks for full implementation and testing

**Phase 1 (Vault PKI)**: 2-3 days
**Phase 2 (Helm Updates)**: 3-4 days
**Phase 3 (Trust Distribution)**: 2-3 days
**Phase 4 (Rotation)**: 2-3 days
**Phase 5 (Security)**: 2-3 days
**Testing**: 3-5 days

**Total**: 14-21 business days
