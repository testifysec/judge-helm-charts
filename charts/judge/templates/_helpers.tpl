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
Istio Ingress Hostname Helpers
These construct public-facing hostnames for VirtualServices.
Format: {subdomain}.{istio.domain}
Users can override subdomains via istio.hosts.* in values.yaml
*/}}
{{- define "judge.ingress.host.gateway" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.gateway | default "gateway" }}{{ else }}gateway{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.web" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.web | default "judge" }}{{ else }}judge{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.api" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.api | default "api" }}{{ else }}api{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.fulcio" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.fulcio | default "fulcio" }}{{ else }}fulcio{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.dex" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.dex | default "dex" }}{{ else }}dex{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.tsa" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.tsa | default "tsa" }}{{ else }}tsa{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.kratos" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.kratos | default "kratos" }}{{ else }}kratos{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{- define "judge.ingress.host.login" -}}
{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ if .Values.istio }}{{ .Values.istio.domain }}{{ else }}{{ .Values.global.domain }}{{ end }}
{{- end -}}

{{/*
Registry URL Helper
Returns AWS Marketplace ECR if enabled, otherwise uses configured registry
AWS Marketplace ECR: Static account 709825985650 (requires active subscription)
*/}}
{{- define "judge.registry.url" -}}
{{- if .Values.global.registry.awsMarketplace -}}
709825985650.dkr.ecr.us-east-1.amazonaws.com
{{- else -}}
{{ .Values.global.registry.url }}
{{- end -}}
{{- end -}}

{{/*
Registry Repository Helper
AWS Marketplace uses direct format (no repository path)
Other registries may have repository paths
*/}}
{{- define "judge.registry.repository" -}}
{{- if .Values.global.registry.awsMarketplace -}}
{{- /* Marketplace uses direct format: 709825985650.dkr.ecr.us-east-1.amazonaws.com/image-name */ -}}
{{- else -}}
{{ .Values.global.registry.repository }}
{{- end -}}
{{- end -}}

{{/*
Render the imageRepository with the global and chart specific values.
Supports AWS Marketplace ECR, standard ECR, GCP Artifact Registry, and custom registries
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- $registryUrl := include "judge.registry.url" . }}
{{- $repository := include "judge.registry.repository" . }}
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
  {{- if .Values.global.registry.repository -}}
    {{- printf "%s/%s/%s:%s" .Values.global.registry.url .Values.global.registry.repository $gatewayName $tag -}}
  {{- else -}}
    {{- printf "%s/%s:%s" .Values.global.registry.url $gatewayName $tag -}}
  {{- end -}}
{{- end -}}


{{- define "judge.gateway.kratosUrl" -}}
  {{- $kratosName := default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- printf "http://%s-%s-public.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{/*
Service URL helpers
These construct internal cluster service URLs using release name pattern
Format: http://{releaseName}-{serviceName}.{namespace}.svc.cluster.local:{port}
*/}}
{{- define "judge.service.archivistaUrl" -}}
{{- $archivistaName := default "judge-archivista" .Values.archivista.nameOverride -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8082" .Release.Name $archivistaName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.judgeApiUrl" -}}
{{- $judgeApiName := default "judge-api" (index .Values "judge-api" "nameOverride") -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080" .Release.Name $judgeApiName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.gatewayUrl" -}}
{{- printf "http://%s-judge-gateway.%s.svc.cluster.local:4000" .Release.Name .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.aiProxyUrl" -}}
{{- $aiProxyName := default "judge-ai-proxy" (index .Values "judge-ai-proxy" "nameOverride") -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080/" .Release.Name $aiProxyName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosAdminUrl" -}}
  {{- $kratosName := default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- printf "http://%s-%s-admin.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosPublicUrl" -}}
  {{- $kratosName := default "judge-kratos" .Values.kratos.nameOverride -}}
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
https://{{ if .Values.istio }}{{ .Values.istio.hosts.kratos | default "kratos" }}{{ else }}kratos{{ end }}.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.login" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.judge" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.web | default "judge" }}{{ else }}judge{{ end }}.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.dex" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.dex | default "dex" }}{{ else }}dex{{ end }}.{{ .Values.global.domain }}
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
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/error
{{- end -}}

{{- define "judge.url.loginSettings" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/settings
{{- end -}}

{{- define "judge.url.loginRecovery" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/recovery
{{- end -}}

{{- define "judge.url.loginVerification" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/verification
{{- end -}}

{{- define "judge.url.loginBase" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/
{{- end -}}

{{- define "judge.url.loginLogin" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/login
{{- end -}}

{{- define "judge.url.loginRegistration" -}}
https://{{ if .Values.istio }}{{ .Values.istio.hosts.login | default "login" }}{{ else }}login{{ end }}.{{ .Values.global.domain }}/registration
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
{{- $domain := .Values.global.domain -}}
{{- $kratosSubdomain := "kratos" -}}
{{- $loginSubdomain := "login" -}}
{{- $webSubdomain := "judge" -}}
{{- if .Values.istio -}}
{{- $kratosSubdomain = .Values.istio.hosts.kratos | default "kratos" -}}
{{- $loginSubdomain = .Values.istio.hosts.login | default "login" -}}
{{- $webSubdomain = .Values.istio.hosts.web | default "judge" -}}
{{- end -}}
{{- $kratosUrl := printf "https://%s.%s" $kratosSubdomain $domain -}}
{{- $loginUrl := printf "https://%s.%s" $loginSubdomain $domain -}}
{{- $judgeUrl := printf "https://%s.%s" $webSubdomain $domain -}}
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
{{- if .Values.global.dev -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/archivista?sslmode=disable
{{- else -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/archivista?sslmode=require
{{- end -}}
{{- end -}}

{{- define "judge.database.endpoint.kratos" -}}
{{- if .Values.global.dev -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/kratos?sslmode=disable
{{- else -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/kratos?sslmode=require
{{- end -}}
{{- end -}}

{{- define "judge.database.endpoint.judgeApi" -}}
{{- if .Values.global.dev -}}
postgres://{{ .Values.global.devDatabase.username | default "judge" }}:{{ .Values.global.devDatabase.password | default "dev-preview-password" }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/judge_api?sslmode=disable
{{- else -}}
postgres://{{ .Values.global.database.username }}:{{ .Values.global.secrets.database.passwordEncoded }}@{{ .Values.global.database.aws.endpoint }}:{{ .Values.global.database.port }}/judge_api?sslmode=require
{{- end -}}
{{- end -}}

{{/*
Storage Endpoint Helpers
Returns LocalStack endpoint for dev mode, S3 endpoint for production
*/}}
{{- define "judge.storage.endpoint.dev" -}}
{{- if .Values.global.dev -}}
http://{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
{{ .Values.global.storage.aws.endpoint }}
{{- end -}}
{{- end -}}

{{- define "judge.storage.useTLS.dev" -}}
{{- if .Values.global.dev -}}
false
{{- else -}}
{{ .Values.global.storage.aws.useTLS }}
{{- end -}}
{{- end -}}

{{- define "judge.storage.credentialType.dev" -}}
{{- if .Values.global.dev -}}
static
{{- else -}}
{{ .Values.global.storage.aws.credentialType }}
{{- end -}}
{{- end -}}

{{/*
Messaging Endpoint Helpers
Returns LocalStack SNS/SQS configuration for dev mode, AWS for production
*/}}
{{- define "judge.messaging.endpoint.dev" -}}
{{- if .Values.global.dev -}}
http://{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
https://sns.{{ include "judge.messaging.region" . }}.amazonaws.com
{{- end -}}
{{- end -}}

{{- define "judge.messaging.region.dev" -}}
{{- if .Values.global.dev -}}
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
{{- if .Values.global.dev -}}
{{ .Release.Name }}-localstack.{{ .Release.Namespace }}.svc.cluster.local:4566
{{- else -}}
s3.amazonaws.com
{{- end -}}
{{- end -}}

{{/*
S3 Use TLS - Returns "true" for prod, "false" for dev (LocalStack)
*/}}
{{- define "judge.s3.useTLS" -}}
{{- if .Values.global.dev -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
S3 Credential Type - Returns IAM for prod, static for dev
*/}}
{{- define "judge.s3.credentialType" -}}
{{- if .Values.global.dev -}}
static
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
{{- if .Values.global.dev -}}
archivista
{{- else -}}
{{ include "judge.aws.s3.archivistaBucket" . }}
{{- end -}}
{{- end -}}

{{- define "judge.s3.archivista.storageBackend" -}}
{{- if .Values.global.dev -}}
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
{{- if .Values.global.dev -}}
judge
{{- else -}}
{{ include "judge.aws.s3.judgeApiBucket" . }}
{{- end -}}
{{- end -}}
