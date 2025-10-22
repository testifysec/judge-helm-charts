{{/*
Validate that istio.domain matches global.domain.
This prevents configuration drift where URLs use different domains.
Usage: {{ include "judge.validateDomain" . }}
*/}}
{{- define "judge.validateDomain" -}}
{{- if .Values.istio -}}
{{- if .Values.istio.enabled -}}
{{- if ne .Values.global.domain .Values.istio.domain -}}
{{- fail (printf "ERROR: global.domain (%s) MUST match istio.domain (%s). Update istio.domain in values.yaml to match global.domain." .Values.global.domain .Values.istio.domain) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
ArgoCD Job Annotations Helper
Returns ArgoCD sync options annotation when global.argocd.enabled is true.
Required for proper Job management in ArgoCD (Jobs are immutable).
Usage: {{ include "judge.argocd.jobAnnotations" . | nindent 4 }}
*/}}
{{- define "judge.argocd.jobAnnotations" -}}
{{- if and .Values.global (and .Values.global.argocd .Values.global.argocd.enabled) -}}
argocd.argoproj.io/sync-options: "Force=true,Replace=true"
{{- end -}}
{{- end -}}

{{/*
Istio Ingress Hostname Helpers
These construct public-facing hostnames for VirtualServices.
Format: {subdomain}.{istio.domain}
Users can override subdomains via istio.hosts.* OR global.istio.hosts.* in values.yaml
Priority: root istio.* → global.istio.* → defaults
*/}}
{{- define "judge.ingress.host.gateway" -}}
{{ include "judge.istio.host" (dict "service" "gateway" "default" "gateway" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.web" -}}
{{ include "judge.istio.host" (dict "service" "web" "default" "judge" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.api" -}}
{{ include "judge.istio.host" (dict "service" "api" "default" "api" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.fulcio" -}}
{{ include "judge.istio.host" (dict "service" "fulcio" "default" "fulcio" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.dex" -}}
{{ include "judge.istio.host" (dict "service" "dex" "default" "dex" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.tsa" -}}
{{ include "judge.istio.host" (dict "service" "tsa" "default" "tsa" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.kratos" -}}
{{ include "judge.istio.host" (dict "service" "kratos" "default" "kratos" "context" .) }}
{{- end -}}

{{- define "judge.ingress.host.login" -}}
{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}
{{- end -}}

{{/*
Check if Marketplace ECR is enabled (consolidated format only)
Use: global.registry.marketplace.enabled: true
*/}}
{{- define "judge.registry.marketplaceEnabled" -}}
{{- if and .Values.global.registry.marketplace .Values.global.registry.marketplace.enabled -}}
{{- true -}}
{{- else -}}
{{- false -}}
{{- end -}}
{{- end -}}

{{/*
Registry URL Helper
Returns AWS Marketplace ECR if enabled, otherwise uses configured registry
AWS Marketplace ECR: Static account 709825985650 (requires active subscription)

When marketplace is enabled, account (709825985650) and region (us-east-1) are hardcoded.
*/}}
{{- define "judge.registry.url" -}}
{{- $marketplaceEnabled := include "judge.registry.marketplaceEnabled" . -}}
{{- if eq $marketplaceEnabled "true" -}}
709825985650.dkr.ecr.us-east-1.amazonaws.com
{{- else -}}
{{ .Values.global.registry.url }}
{{- end -}}
{{- end -}}

{{/*
Registry Repository Helper
Returns the marketplace seller namespace (hardcoded to "testifysec") or custom repository

Supports:
- Old format: global.registry.repository: testifysec
- New format: global.registry.marketplace.enabled: true (seller is always "testifysec")
*/}}
{{- define "judge.registry.repository" -}}
{{- $marketplaceEnabled := include "judge.registry.marketplaceEnabled" . -}}
{{- if eq $marketplaceEnabled "true" -}}
{{- /* Marketplace seller namespace is hardcoded constant: testifysec */ -}}
testifysec
{{- else -}}
{{- /* Non-marketplace uses configured repository */ -}}
{{ .Values.global.registry.repository }}
{{- end -}}
{{- end -}}

{{/*
Render the imageRepository with the global and chart specific values.
Precedence: .Values.image.repository (if non-empty) → judge.registry.repository (marketplace-aware) → ""
Supports AWS Marketplace ECR, standard ECR, GCP Artifact Registry, and custom registries
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- $registryUrl := include "judge.registry.url" . }}
{{- $localRepo := ((.Values.image).repository) | default "" }}
{{- $globalRepo := include "judge.registry.repository" . }}
{{- $repository := "" }}
{{- if ne $localRepo "" }}
  {{- $repository = $localRepo }}
{{- else }}
  {{- $repository = $globalRepo }}
{{- end }}
{{- if eq $repository "" }}
{{- printf "%s/%s" $registryUrl $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" $registryUrl $repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Render the imageRepository with the global and chart specific values, but for judge-web which in legacy was just named 'web'
Supports AWS Marketplace ECR, standard ECR, GCP Artifact Registry, and custom registries
*/}}
{{- define "judge-web.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride -}}
{{- $registryUrl := include "judge.registry.url" . }}
{{- $repository := include "judge.registry.repository" . }}
{{- if eq $repository "" }}
{{- printf "%s/%s" $registryUrl $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" $registryUrl $repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "judge.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "judge.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "judge.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "judge.labels" -}}
helm.sh/chart: {{ include "judge.chart" . }}
{{ include "judge.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "judge.selectorLabels" -}}
app.kubernetes.io/name: {{ include "judge.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "judge.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "judge.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "judge.gateway.fullname" -}}
  {{- if .Values.gateway.fullnameOverride -}}
    {{- .Values.gateway.fullnameOverride | trunc 63 | trimSuffix "-" }}
  {{- else -}}
    {{- printf "%s-%s" .Release.Name (include "judge.gateway" .) | trunc 63 | trimSuffix "-" }}
  {{- end -}}
{{- end }}

{{- define "judge.gateway" -}}
  {{- default "judge-gateway" .Values.gateway.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "judge.gateway.image" -}}
  {{- $gatewayName := default "judge-gateway" .Values.gateway.nameOverride -}}
  {{- $tag := tpl (.Values.gateway.image.tag | default (include "judge.image.defaultTag" .) | toString) . -}}
  {{- $registryUrl := include "judge.registry.url" . -}}
  {{- $repository := include "judge.registry.repository" . -}}
  {{- if $repository -}}
    {{- printf "%s/%s/%s:%s" $registryUrl $repository $gatewayName $tag -}}
  {{- else -}}
    {{- printf "%s/%s:%s" $registryUrl $gatewayName $tag -}}
  {{- end -}}
{{- end -}}


{{- define "judge.gateway.kratosUrl" -}}
{{- $kratosName := "judge-kratos" -}}
{{- if hasKey .Values "kratos" -}}
  {{- if .Values.kratos -}}
    {{- $kratosName = default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s-public.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{/*
Service URL helpers
These construct internal cluster service URLs using release name pattern
Format: http://{releaseName}-{serviceName}.{namespace}.svc.cluster.local:{port}
*/}}
{{- define "judge.service.archivistaUrl" -}}
{{- $archivistaName := "judge-archivista" -}}
{{- if hasKey .Values "archivista" -}}
  {{- if .Values.archivista -}}
    {{- $archivistaName = default "judge-archivista" .Values.archivista.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8082" .Release.Name $archivistaName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.judgeApiUrl" -}}
{{- $judgeApiName := "judge-api" -}}
{{- if hasKey .Values "judge-api" -}}
  {{- $judgeApiName = default "judge-api" ((index .Values "judge-api").nameOverride) -}}
{{- end -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080" .Release.Name $judgeApiName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.gatewayUrl" -}}
{{- printf "http://%s-judge-gateway.%s.svc.cluster.local:4000" .Release.Name .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.aiProxyUrl" -}}
{{- $aiProxyName := "judge-ai-proxy" -}}
{{- if hasKey .Values "judge-ai-proxy" -}}
  {{- $aiProxyName = default "judge-ai-proxy" ((index .Values "judge-ai-proxy").nameOverride) -}}
{{- end -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080/" .Release.Name $aiProxyName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosAdminUrl" -}}
{{- $kratosName := "judge-kratos" -}}
{{- if hasKey .Values "kratos" -}}
  {{- if .Values.kratos -}}
    {{- $kratosName = default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s-admin.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosPublicUrl" -}}
{{- $kratosName := "judge-kratos" -}}
{{- if hasKey .Values "kratos" -}}
  {{- if .Values.kratos -}}
    {{- $kratosName = default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s-public.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.judgeApiWebhookUrl" -}}
{{- $judgeApiName := "judge-api" -}}
{{- if hasKey .Values "judge-api" -}}
  {{- $judgeApiName = default "judge-api" ((index .Values "judge-api").nameOverride) -}}
{{- end -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080/webhook/defaulttenant" .Release.Name $judgeApiName .Release.Namespace -}}
{{- end -}}

{{- define "judge.httpproxy" -}}
  {{- printf "%s-httpproxy" (include "judge.fullname" .) -}}
{{- end -}}

{{/*
Database PostgreSQL connection string helpers
These construct connection strings from global.database and global.secrets configuration
Supports provider pattern (currently AWS RDS only)
*/}}
{{- define "judge.rds.archivistaDsn" -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/archivista?sslmode=require
{{- end -}}

{{- define "judge.rds.kratosDsn" -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/kratos?sslmode=require
{{- end -}}

{{- define "judge.rds.judgeApiDsn" -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/judge_api?sslmode=require
{{- end -}}

{{/*
Domain URL helpers
These construct URLs from global.domain configuration
*/}}
{{- define "judge.url.kratos" -}}
https://{{ include "judge.istio.host" (dict "service" "kratos" "default" "kratos" "context" .) }}
{{- end -}}

{{- define "judge.url.login" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}
{{- end -}}

{{- define "judge.url.judge" -}}
https://{{ include "judge.istio.host" (dict "service" "web" "default" "judge" "context" .) }}
{{- end -}}

{{- define "judge.url.dex" -}}
https://{{ include "judge.istio.host" (dict "service" "dex" "default" "dex" "context" .) }}
{{- end -}}

{{- define "judge.url.wildcard" -}}
https://*.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.root" -}}
https://{{ .Values.global.domain }}
{{- end -}}

{{/*
Image tag helper
Returns the default image tag from global.version
*/}}
{{- define "judge.image.defaultTag" -}}
{{ .Values.global.version }}
{{- end -}}

{{/*
IAM Role ARN helpers
*/}}
{{- define "judge.iam.archivistaRole" -}}
arn:aws:iam::{{ .Values.global.cloud.aws.accountId }}:role/{{ .Values.global.cloud.aws.iamRoles.archivista }}
{{- end -}}

{{- define "judge.iam.judgeApiRole" -}}
arn:aws:iam::{{ .Values.global.cloud.aws.accountId }}:role/{{ .Values.global.cloud.aws.iamRoles.judgeApi }}
{{- end -}}

{{/*
AWS Configuration Helpers
Support both legacy global.cloud.aws and new global.aws patterns
*/}}

{{- define "judge.aws.accountId" -}}
{{- if .Values.global.aws.accountId -}}
{{ .Values.global.aws.accountId }}
{{- else if .Values.global.cloud.aws.accountId -}}
{{ .Values.global.cloud.aws.accountId }}
{{- end -}}
{{- end -}}

{{- define "judge.aws.region" -}}
{{- if .Values.global.aws.region -}}
{{ .Values.global.aws.region }}
{{- else if .Values.global.cloud.aws.region -}}
{{ .Values.global.cloud.aws.region }}
{{- else -}}
us-east-1
{{- end -}}
{{- end -}}

{{- define "judge.aws.prefix" -}}
{{ .Values.global.aws.prefix | default "judge" }}
{{- end -}}

{{/*
AWS IRSA IAM Role ARN helpers
Constructs: arn:aws:iam::{accountId}:role/{prefix}-{service}
*/}}
{{- define "judge.aws.iam.judgeApiRole" -}}
arn:aws:iam::{{ include "judge.aws.accountId" . }}:role/{{ include "judge.aws.prefix" . }}-judge-api
{{- end -}}

{{- define "judge.aws.iam.archivistaRole" -}}
arn:aws:iam::{{ include "judge.aws.accountId" . }}:role/{{ include "judge.aws.prefix" . }}-archivista
{{- end -}}

{{- define "judge.aws.iam.kratosRole" -}}
arn:aws:iam::{{ include "judge.aws.accountId" . }}:role/{{ include "judge.aws.prefix" . }}-kratos
{{- end -}}

{{/*
AWS S3 Bucket Helpers
Constructs: {prefix}-{service}
*/}}
{{- define "judge.aws.s3.judgeApiBucket" -}}
{{ include "judge.aws.prefix" . }}-judge
{{- end -}}

{{- define "judge.aws.s3.archivistaBucket" -}}
{{ include "judge.aws.prefix" . }}-archivista
{{- end -}}

{{/*
AWS SNS/SQS Helpers
These helpers provide Dapr pubsub configuration for SNS/SQS messaging
Supports dev mode (LocalStack) and production (AWS) automatically
*/}}
{{- define "judge.aws.sns.topic" -}}
{{ include "judge.aws.prefix" . }}-archivista-attestations
{{- end -}}

{{- define "judge.aws.sqs.queue" -}}
{{ include "judge.aws.prefix" . }}-archivista-attestations
{{- end -}}

{{/*
Dapr pubsub-compatible aliases (for dapr-pubsub.yaml template)
*/}}
{{- define "judge.aws.sns.topicName" -}}
{{ include "judge.aws.sns.topic" . }}
{{- end -}}

{{- define "judge.aws.sqs.queueName" -}}
{{ include "judge.aws.sqs.queue" . }}
{{- end -}}

{{- define "judge.aws.sns.region" -}}
{{ include "judge.aws.region" . }}
{{- end -}}

{{/*
AWS IRSA Annotation Helper
Auto-generates eks.amazonaws.com/role-arn annotation when IRSA is enabled
Usage: {{ include "judge.aws.irsa.annotations" (dict "service" "archivista" "root" .) }}
Returns: map with annotation when enabled, empty map when disabled
DRY: Single source of truth - global.aws configuration
UX: One toggle (global.aws.irsa.enabled) controls all services
*/}}
{{- define "judge.aws.irsa.annotations" -}}
{{- $service := .service -}}
{{- $root := .root -}}
{{- if and $root.Values.global.aws $root.Values.global.aws.irsa $root.Values.global.aws.irsa.enabled -}}
eks.amazonaws.com/role-arn: arn:aws:iam::{{ include "judge.aws.accountId" $root }}:role/{{ include "judge.aws.prefix" $root }}-{{ $service }}
{{- end -}}
{{- end -}}

{{/*
Storage helpers
These construct blob storage configuration from global.storage
Supports provider pattern (currently AWS S3 only)
*/}}
{{- define "judge.storage.endpoint" -}}
{{ .Values.global.storage.aws.endpoint }}
{{- end -}}

{{- define "judge.storage.bucket.archivista" -}}
{{ .Values.global.storage.buckets.archivista }}
{{- end -}}

{{- define "judge.storage.bucket.judgeApi" -}}
{{ .Values.global.storage.buckets.judgeApi }}
{{- end -}}

{{- define "judge.storage.credentialType" -}}
{{ .Values.global.storage.aws.credentialType }}
{{- end -}}

{{- define "judge.storage.useTLS" -}}
{{ .Values.global.storage.aws.useTLS }}
{{- end -}}

{{/*
Messaging helpers
These construct queue/pubsub configuration from global.messaging
Supports provider pattern (currently AWS SNS/SQS only)
*/}}
{{- define "judge.messaging.region" -}}
{{ .Values.global.messaging.aws.region }}
{{- end -}}

{{- define "judge.messaging.topic.archivistaAttestations" -}}
{{ .Values.global.messaging.topics.archivistaAttestations }}
{{- end -}}

{{- define "judge.messaging.snsTopicName" -}}
{{ .Values.global.messaging.aws.snsTopicName }}
{{- end -}}

{{- define "judge.messaging.sqsQueueName" -}}
{{ .Values.global.messaging.aws.sqsQueueName }}
{{- end -}}

{{/*
Domain helper
Returns the domain from global configuration
Eliminates direct .Values references in favor of helper pattern
*/}}
{{- define "judge.global.domain" -}}
{{ .Values.global.domain }}
{{- end -}}

{{/*
Kratos Flow URL Helpers
These helpers provide full URLs for Kratos selfservice flows,
eliminating string concatenation in values files
*/}}

{{- define "judge.url.loginError" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/error
{{- end -}}

{{- define "judge.url.loginSettings" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/settings
{{- end -}}

{{- define "judge.url.loginRecovery" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/recovery
{{- end -}}

{{- define "judge.url.loginVerification" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/verification
{{- end -}}

{{- define "judge.url.loginBase" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/
{{- end -}}

{{- define "judge.url.loginLogin" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/login
{{- end -}}

{{- define "judge.url.loginRegistration" -}}
https://{{ include "judge.istio.host" (dict "service" "login" "default" "login" "context" .) }}/registration
{{- end -}}

{{/*
Kratos Complete Config Factory
Generates the entire kratos configuration from minimal customer input.
Customers only need to provide: domain, OIDC providers
Everything else is derived automatically.

Kratos URL Strategy (CRITICAL):
- kratosUrl: MUST be external (https://kratos.testifysec-demo.xyz)
  Why: Kratos uses serve.public.base_url for OAuth redirect URLs sent to browsers.
       Using cluster.local breaks OAuth - browsers cannot access internal DNS.
       Service-to-service auth uses internal URLs (defined per-component).

- loginUrl/judgeUrl: External URLs for browser-facing redirects.
- wildcardUrl/rootUrl: External URLs for allowed_return_urls post-auth.
*/}}
{{- define "judge.kratos.config.complete" -}}
{{- $kratosUrl := printf "https://%s" (include "judge.istio.host" (dict "service" "kratos" "default" "kratos" "context" .)) -}}
{{- $loginUrl := printf "https://%s" (include "judge.istio.host" (dict "service" "login" "default" "login" "context" .)) -}}
{{- $judgeUrl := printf "https://%s" (include "judge.istio.host" (dict "service" "web" "default" "judge" "context" .)) -}}
{{- $domain := .Values.global.domain -}}
{{- $wildcardUrl := printf "https://*.%s" $domain -}}
{{- $rootUrl := printf "https://%s" $domain -}}
cookies:
  domain: {{ $domain }}
  path: /
  same_site: Lax
courier:
  smtp:
    connection_uri: smtps://test:test@mailslurper:1025/?skip_ssl_verify=true
identity:
  default_schema_id: default
  schemas:
  - id: default
    url: base64://eyIkaWQiOiJodHRwczovL3NjaGVtYXMub3J5LnNoL3ByZXNldHMva3JhdG9zL3F1aWNrc3RhcnQvZW1haWwtcGFzc3dvcmQvaWRlbnRpdHkuc2NoZW1hLmpzb24iLCIkc2NoZW1hIjoiaHR0cDovL2pzb24tc2NoZW1hLm9yZy9kcmFmdC0wNy9zY2hlbWEjIiwidGl0bGUiOiJQZXJzb24iLCJ0eXBlIjoib2JqZWN0IiwicHJvcGVydGllcyI6eyJ0cmFpdHMiOnsidHlwZSI6Im9iamVjdCIsInByb3BlcnRpZXMiOnsiZW1haWwiOnsidHlwZSI6InN0cmluZyIsImZvcm1hdCI6ImVtYWlsIiwidGl0bGUiOiJFLU1haWwiLCJtaW5MZW5ndGgiOjMsIm9yeS5zaC9rcmF0b3MiOnsiY3JlZGVudGlhbHMiOnsid2ViYXV0aG4iOnsiaWRlbnRpZmllciI6dHJ1ZX19LCJ2ZXJpZmljYXRpb24iOnsidmlhIjoiZW1haWwifX19LCJuYW1lIjp7InR5cGUiOiJzdHJpbmciLCJ0aXRsZSI6IkZ1bGwgTmFtZSIsIm1pbkxlbmd0aCI6MX19LCJyZXF1aXJlZCI6WyJlbWFpbCIsIm5hbWUiXSwiYWRkaXRpb25hbFByb3BlcnRpZXMiOmZhbHNlfSwibWV0YWRhdGFfcHVibGljIjp7ImFzc2lnbmVkX3RlbmFudHMiOnsidHlwZSI6ImFycmF5IiwiaXRlbXMiOlt7InR5cGUiOiJzdHJpbmcifV19fX19Cg==
  - id: other
    url: base64://eyIkaWQiOiJvcnk6Ly9pZGVudGl0eS1vdGhlci1zY2hlbWEiLCIkc2NoZW1hIjoiaHR0cDovL2pzb24tc2NoZW1hLm9yZy9kcmFmdC0wNy9zY2hlbWEjIiwidGl0bGUiOiJJZGVudGl0eU90aGVyU2NoZW1hIiwidHlwZSI6Im9iamVjdCIsInByb3BlcnRpZXMiOnsidHJhaXRzIjp7InR5cGUiOiJvYmplY3QiLCJwcm9wZXJ0aWVzIjp7Im90aGVyIjp7InR5cGUiOiJzdHJpbmcifSwiZW1haWwiOnsidHlwZSI6InN0cmluZyIsInRpdGxlIjoiZW1haWwiLCJvcnkuc2gva3JhdG9zIjp7ImNyZWRlbnRpYWxzIjp7InBhc3N3b3JkIjp7ImlkZW50aWZpZXIiOnRydWV9fX19LCJuYW1lIjp7InR5cGUiOiJzdHJpbmciLCJ0aXRsZSI6IkZ1bGwgTmFtZSIsIm1pbkxlbmd0aCI6MX19LCJyZXF1aXJlZCI6WyJvdGhlciIsImVtYWlsIiwibmFtZSJdLCJhZGRpdGlvbmFsUHJvcGVydGllcyI6dHJ1ZX19fQo=
log:
  format: json
  leak_sensitive_values: false
  level: info
selfservice:
  allowed_return_urls:
  - {{ $loginUrl }}
  - {{ $loginUrl }}/post-auth
  - {{ $kratosUrl }}
  - {{ $judgeUrl }}
  default_browser_return_url: {{ $judgeUrl }}
  flows:
    error:
      ui_url: {{ $loginUrl }}/error
    login:
      after:
        default_browser_return_url: {{ $judgeUrl }}
      lifespan: 10m
      ui_url: {{ $loginUrl }}/login
    logout:
      after:
        default_browser_return_url: {{ $loginUrl }}/login
    recovery:
      enabled: true
      ui_url: {{ $loginUrl }}/recovery
    registration:
      after:
        oidc:
          hooks:
          - hook: session
          - config:
              body: base64://ZnVuY3Rpb24oY3R4KSB7CiAgICAgIGlkZW50aXR5SWQ6IGN0eC5pZGVudGl0eS5pZCwKICAgICAgdHJhaXRzOiBjdHguaWRlbnRpdHkudHJhaXRzCn0=
              method: POST
              url: {{ include "judge.service.judgeApiWebhookUrl" . }}
            hook: web_hook
      lifespan: 10m
      ui_url: {{ $loginUrl }}/registration
    settings:
      privileged_session_max_age: 15m
      required_aal: highest_available
      ui_url: {{ $loginUrl }}/settings
    verification:
      after:
        default_browser_return_url: {{ $loginUrl }}/
      enabled: true
      ui_url: {{ $loginUrl }}/verification
  methods:
    oidc:
      enabled: {{ default true (dig "oidc" "enabled" nil .Values.global) }}
      config:
        providers: {{- if and .Values.global.oidc .Values.global.oidc.providers }}
        {{- range .Values.global.oidc.providers }}
        - id: {{ .id }}
          provider: {{ .provider }}
          {{- if eq .provider "github-app" }}
          client_id: ${OIDC_GITHUB_CLIENT_ID}
          client_secret: ${OIDC_GITHUB_CLIENT_SECRET}
          issuer_url: https://github.com
          mapper_url: file:///etc/config/kratos/github.jsonnet
          scope:
            - user
            - repo
            - read:org
          {{- else }}
          client_id: {{ .client_id }}
          client_secret: {{ .client_secret }}
          {{- if .issuer_url }}
          issuer_url: {{ .issuer_url }}
          {{- end }}
          {{- if .mapper_url }}
          mapper_url: {{ .mapper_url }}
          {{- end }}
          {{- if .scope }}
          scope: {{- toYaml .scope | nindent 10 }}
          {{- end }}
          {{- end }}
        {{- end }}
        {{- else }} []
        {{- end }}
    password:
      enabled: false
serve:
  admin:
    base_url: {{ include "judge.service.kratosAdminUrl" . }}
    port: 4433
  public:
    base_url: {{ $kratosUrl }}
    cors:
      allowed_headers:
      - Authorization
      - Cookie
      - Content-Type
      allowed_methods:
      - POST
      - GET
      - PUT
      - PATCH
      - DELETE
      allowed_origins:
      - {{ $wildcardUrl }}
      - {{ $rootUrl }}
      enabled: true
      exposed_headers:
      - Content-Type
      - Set-Cookie
    port: 4434
{{- end -}}

{{/*
Dev-Mode Infrastructure Helpers
These helpers switch between dev infrastructure (LocalStack/PostgreSQL) and production (AWS RDS/S3/SNS/SQS)
based on the global.dev flag. This enables self-contained preview environments with zero AWS dependencies.
*/}}

{{/*
Database Endpoint Helpers
Returns PostgreSQL DSN for dev mode, RDS DSN for production
*/}}
{{- define "judge.database.endpoint.archivista" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/archivista?sslmode=disable
{{- else -}}
{{- $username := "archivista" -}}
{{- $password := "PLACEHOLDER_PASSWORD" -}}
{{- $endpoint := "localhost" -}}
{{- $port := "5432" -}}
{{- if and .Values.global .Values.global.database -}}
  {{- $username = default "archivista" .Values.global.database.username -}}
  {{- $port = default "5432" .Values.global.database.port -}}
  {{- if .Values.global.database.aws -}}
    {{- $endpoint = default "localhost" .Values.global.database.aws.endpoint -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.global .Values.global.secrets .Values.global.secrets.database -}}
  {{- $password = default "PLACEHOLDER_PASSWORD" .Values.global.secrets.database.passwordEncoded -}}
{{- end -}}
postgres://{{ $username }}:{{ $password }}@{{ $endpoint }}:{{ $port }}/archivista?sslmode=require
{{- end -}}
{{- end -}}

{{- define "judge.database.endpoint.kratos" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/kratos?sslmode=disable
{{- else -}}
{{- $username := "kratos" -}}
{{- $password := "PLACEHOLDER_PASSWORD" -}}
{{- $endpoint := "localhost" -}}
{{- $port := "5432" -}}
{{- if and .Values.global .Values.global.database -}}
  {{- $username = default "kratos" .Values.global.database.username -}}
  {{- $port = default "5432" .Values.global.database.port -}}
  {{- if .Values.global.database.aws -}}
    {{- $endpoint = default "localhost" .Values.global.database.aws.endpoint -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.global .Values.global.secrets .Values.global.secrets.database -}}
  {{- $password = default "PLACEHOLDER_PASSWORD" .Values.global.secrets.database.passwordEncoded -}}
{{- end -}}
postgres://{{ $username }}:{{ $password }}@{{ $endpoint }}:{{ $port }}/kratos?sslmode=require
{{- end -}}
{{- end -}}

{{- define "judge.database.endpoint.judgeApi" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/judge_api?sslmode=disable
{{- else -}}
{{- $username := "judge" -}}
{{- $password := "PLACEHOLDER_PASSWORD" -}}
{{- $endpoint := "localhost" -}}
{{- $port := "5432" -}}
{{- if and .Values.global .Values.global.database -}}
  {{- $username = default "judge" .Values.global.database.username -}}
  {{- $port = default "5432" .Values.global.database.port -}}
  {{- if .Values.global.database.aws -}}
    {{- $endpoint = default "localhost" .Values.global.database.aws.endpoint -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.global .Values.global.secrets .Values.global.secrets.database -}}
  {{- $password = default "PLACEHOLDER_PASSWORD" .Values.global.secrets.database.passwordEncoded -}}
{{- end -}}
postgres://{{ $username }}:{{ $password }}@{{ $endpoint }}:{{ $port }}/judge_api?sslmode=require
{{- end -}}
{{- end -}}

{{/*
Storage Endpoint Helpers
Returns LocalStack endpoint for dev mode, S3 endpoint for production
*/}}
{{- define "judge.storage.endpoint.dev" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
http://{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
{{ .Values.global.storage.aws.endpoint }}
{{- end -}}
{{- end -}}

{{- define "judge.storage.useTLS.dev" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
false
{{- else -}}
{{ .Values.global.storage.aws.useTLS }}
{{- end -}}
{{- end -}}

{{- define "judge.storage.credentialType.dev" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
ACCESS_KEY
{{- else -}}
{{ .Values.global.storage.aws.credentialType }}
{{- end -}}
{{- end -}}

{{/*
Messaging Endpoint Helpers
Returns LocalStack SNS/SQS configuration for dev mode, AWS for production
*/}}
{{- define "judge.messaging.endpoint.dev" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
http://{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
https://sns.{{ include "judge.messaging.region" . }}.amazonaws.com
{{- end -}}
{{- end -}}

{{- define "judge.messaging.region.dev" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
us-east-1
{{- else -}}
{{ .Values.global.messaging.aws.region }}
{{- end -}}
{{- end -}}

{{/*
AWS S3 Blob Storage Configuration Helpers
These helpers provide complete S3 configuration for Judge API and Archivista
Supports dev mode (LocalStack) and production (AWS S3) automatically
Usage in subchart deployment templates:
  - name: BLOB_STORE_ENDPOINT
    value: {{ include "judge.s3.endpoint" . | quote }}
*/}}

{{/*
S3 Endpoint - Returns s3.amazonaws.com for prod, LocalStack for dev
*/}}
{{- define "judge.s3.endpoint" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
s3.amazonaws.com
{{- end -}}
{{- end -}}

{{/*
S3 Use TLS - Returns "true" for prod, "false" for dev (LocalStack)
*/}}
{{- define "judge.s3.useTLS" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
S3 Credential Type - Returns IAM for prod, ACCESS_KEY for dev
*/}}
{{- define "judge.s3.credentialType" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
ACCESS_KEY
{{- else -}}
IAM
{{- end -}}
{{- end -}}

{{/*
S3 Region - Returns configured region from global.aws.region
*/}}
{{- define "judge.s3.region" -}}
{{ include "judge.aws.region" . }}
{{- end -}}

{{/*
Archivista-specific S3 helpers
These use ARCHIVISTA_ prefixed env var names
*/}}
{{- define "judge.s3.archivista.bucketName" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
archivista
{{- else -}}
{{ include "judge.aws.s3.archivistaBucket" . }}
{{- end -}}
{{- end -}}

{{- define "judge.s3.archivista.storageBackend" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
BLOB
{{- else -}}
BLOB
{{- end -}}
{{- end -}}

{{/*
Judge API-specific S3 helpers
These use BLOB_STORE_ prefixed env var names
*/}}
{{- define "judge.s3.judgeApi.bucketName" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
judge
{{- else -}}
{{ include "judge.aws.s3.judgeApiBucket" . }}
{{- end -}}
{{- end -}}

{{/*
================================================================================
GLOBAL VALUES REFACTOR HELPERS
These helpers support the new global values structure with mode, versions, auth, and istio
================================================================================
*/}}

{{/*
Get deployment mode (aws or dev)
Supports both new global.mode and old global.dev for backward compatibility
*/}}
{{- define "judge.mode" -}}
{{- if .Values.global.mode -}}
{{- .Values.global.mode -}}
{{- else if .Values.global.dev -}}
dev
{{- else -}}
aws
{{- end -}}
{{- end -}}

{{/*
Check if in development mode
Returns true if mode=dev or global.dev=true
*/}}
{{- define "judge.isDevelopmentMode" -}}
{{- if eq (include "judge.mode" .) "dev" -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Get image tag for a service - simplified version management
Usage: {{ include "judge.imageTag" (dict "service" "api" "context" .) }}
Precedence:
1. global.versions.{service} - Explicit service version
2. global.versions.platform - Platform-wide default for Judge services
3. .Chart.AppVersion - Chart default
*/}}
{{- define "judge.imageTag" -}}
{{- $service := .service -}}
{{- $context := .context -}}
{{- $tag := "" -}}
{{/* Check global.versions.{service} */}}
{{- if $context.Values.global -}}
  {{- if $context.Values.global.versions -}}
    {{- if hasKey $context.Values.global.versions $service -}}
      {{- $version := index $context.Values.global.versions $service -}}
      {{- if ne $version "" -}}
        {{- $tag = $version -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Fallback: global.versions.platform */}}
{{- if eq $tag "" -}}
  {{- if $context.Values.global -}}
    {{- if $context.Values.global.versions -}}
      {{- if $context.Values.global.versions.platform -}}
        {{- if ne $context.Values.global.versions.platform "" -}}
          {{- $tag = $context.Values.global.versions.platform -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Final fallback: Chart.AppVersion */}}
{{- if eq $tag "" -}}
  {{- $tag = $context.Chart.AppVersion -}}
{{- end -}}
{{- $tag -}}
{{- end -}}

{{/*
Get single domain source
Always uses global.domain, ignores istio.domain
*/}}
{{- define "judge.domain" -}}
{{- .Values.global.domain -}}
{{- end -}}

{{/*
Get GitHub OAuth client ID from new location
Supports both global.auth.github and old location for backward compatibility
*/}}
{{- define "judge.auth.github.clientId" -}}
{{- if .Values.global.auth -}}
  {{- if .Values.global.auth.github -}}
    {{- .Values.global.auth.github.clientId -}}
  {{- else if .Values.global.oidc -}}
    {{- range .Values.global.oidc.providers -}}
      {{- if eq .id "github" -}}
        {{- .clientId -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if .Values.global.oidc -}}
  {{- range .Values.global.oidc.providers -}}
    {{- if eq .id "github" -}}
      {{- .clientId -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get GitHub OAuth client secret from new location
Supports both global.auth.github and old location for backward compatibility
*/}}
{{- define "judge.auth.github.clientSecret" -}}
{{- if .Values.global.auth -}}
  {{- if .Values.global.auth.github -}}
    {{- .Values.global.auth.github.clientSecret -}}
  {{- else if .Values.global.oidc -}}
    {{- range .Values.global.oidc.providers -}}
      {{- if eq .id "github" -}}
        {{- .clientSecret -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if .Values.global.oidc -}}
  {{- range .Values.global.oidc.providers -}}
    {{- if eq .id "github" -}}
      {{- .clientSecret -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get Istio host for a service
Priority: global.istio.hosts.{service} → root istio.hosts.{service} → default
Domain priority: root istio.domain → global.domain
Usage: {{ include "judge.istio.host" (dict "service" "web" "default" "judge" "context" .) }}
*/}}
{{- define "judge.istio.host" -}}
{{- $service := .service -}}
{{- $default := .default -}}
{{- $context := .context -}}
{{- $rootHost := "" -}}
{{- $globalHost := "" -}}
{{/*  DEBUG global check */}}
{{- if and $context.Values.global.istio $context.Values.global.istio.hosts (hasKey $context.Values.global.istio.hosts $service) -}}
  {{- $globalHost = index $context.Values.global.istio.hosts $service -}}
{{- end -}}
{{/*  DEBUG root check */}}
{{- if and $context.Values.istio $context.Values.istio.hosts (hasKey $context.Values.istio.hosts $service) -}}
  {{- $rootHost = index $context.Values.istio.hosts $service -}}
{{- end -}}
{{- $host := coalesce $globalHost $rootHost $default -}}
{{- $istioDomain := "" -}}
{{- if $context.Values.istio -}}
  {{- $istioDomain = $context.Values.istio.domain | default "" -}}
{{- end -}}
{{- $domain := coalesce $istioDomain $context.Values.global.domain -}}
{{- printf "%s.%s" $host $domain -}}
{{- end -}}
