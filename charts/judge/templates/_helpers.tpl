{{/*
Validate that istio.domain matches global.domain.
This prevents configuration drift where URLs use different domains.
Usage: {{ include "judge.validateDomain" . }}
*/}}
{{- define "judge.validateDomain" -}}
{{- if .Values.istio.enabled }}
{{- if ne .Values.global.domain .Values.istio.domain }}
{{- fail (printf "ERROR: global.domain (%s) MUST match istio.domain (%s). Update istio.domain in values.yaml to match global.domain." .Values.global.domain .Values.istio.domain) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Render the imageRepository with the global and chart specific values.
Supports provider pattern (currently AWS ECR only)
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- if eq .Values.global.registry.repository "" }}
{{- printf "%s/%s" .Values.global.registry.url $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" .Values.global.registry.url .Values.global.registry.repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Render the imageRepository with the global and chart specific values, but for judge-web which in legacy was just named 'web'
Supports provider pattern (currently AWS ECR only)
*/}}
{{- define "judge-web.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride -}}
{{- if eq .Values.global.registry.repository "" }}
{{- printf "%s/%s" .Values.global.registry.url $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" .Values.global.registry.url .Values.global.registry.repository $chartName | trimSuffix "/" -}}
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
  {{- $gatewayName := default "gateway" .Values.gateway.nameOverride -}}
  {{- printf "http://kratos-public.%s.svc.cluster.local" .Release.Namespace -}}
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
{{- $gatewayName := default "judge-gateway" .Values.gateway.nameOverride -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:4000" .Release.Name $gatewayName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.aiProxyUrl" -}}
{{- $aiProxyName := default "judge-ai-proxy" (index .Values "judge-ai-proxy" "nameOverride") -}}
{{- printf "http://%s-%s.%s.svc.cluster.local:8080/" .Release.Name $aiProxyName .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosAdminUrl" -}}
  {{- printf "http://kratos-admin.%s.svc.cluster.local" .Release.Namespace -}}
{{- end -}}

{{- define "judge.service.kratosPublicUrl" -}}
  {{- printf "http://kratos-public.%s.svc.cluster.local" .Release.Namespace -}}
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
https://kratos.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.login" -}}
https://login.{{ .Values.global.domain }}
{{- end -}}

{{- define "judge.url.judge" -}}
https://judge.{{ .Values.global.domain }}
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
AWS Region helper
Returns the AWS region from global.cloud configuration
Supports provider pattern (currently AWS only)
*/}}
{{- define "judge.aws.region" -}}
{{ .Values.global.cloud.aws.region }}
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
https://login.{{ .Values.global.domain }}/error
{{- end -}}

{{- define "judge.url.loginSettings" -}}
https://login.{{ .Values.global.domain }}/settings
{{- end -}}

{{- define "judge.url.loginRecovery" -}}
https://login.{{ .Values.global.domain }}/recovery
{{- end -}}

{{- define "judge.url.loginVerification" -}}
https://login.{{ .Values.global.domain }}/verification
{{- end -}}

{{- define "judge.url.loginBase" -}}
https://login.{{ .Values.global.domain }}/
{{- end -}}

{{- define "judge.url.loginLogin" -}}
https://login.{{ .Values.global.domain }}/login
{{- end -}}

{{- define "judge.url.loginRegistration" -}}
https://login.{{ .Values.global.domain }}/registration
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
{{- $kratosUrl := printf "https://kratos.%s" $domain -}}
{{- $loginUrl := printf "https://login.%s" $domain -}}
{{- $judgeUrl := printf "https://judge.%s" $domain -}}
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
  leak_sensitive_values: true
  level: debug
selfservice:
  allowed_return_urls:
  - {{ $loginUrl }}
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
      enabled: {{ .Values.global.oidc.enabled | default true }}
      config:
        providers: {{- toYaml .Values.global.oidc.providers | nindent 8 }}
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
