{{/*
Render the imageRepository with the global and chart specific values.
Precedence: .Values.image.repository (if non-empty) → .Values.global.registry.repository → ""
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- $globalRegistryUrl := "" }}
{{- $globalRepo := "" }}
{{- if .Values.global }}
{{- if .Values.global.registry }}
{{- $globalRegistryUrl = .Values.global.registry.url | default "" }}
{{- $globalRepo = .Values.global.registry.repository | default "" }}
{{- end }}
{{- end }}
{{- $registryUrl := coalesce ((.Values.image).registry) $globalRegistryUrl "ghcr.io" }}
{{- $localRepo := ((.Values.image).repository) | default "" }}
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
Render the imagePullPolicy with the global and chart specific values.
Precedence: .Values.image.pullPolicy (if set) → .Values.global.image.pullPolicy → "IfNotPresent"
*/}}
{{- define "judge.image.pullPolicy" -}}
{{- $localPolicy := "" -}}
{{- if .Values.image -}}
  {{- $localPolicy = .Values.image.pullPolicy | default "" -}}
{{- end -}}
{{- $globalPolicy := "" -}}
{{- if .Values.global -}}
  {{- if .Values.global.image -}}
    {{- $globalPolicy = .Values.global.image.pullPolicy | default "" -}}
  {{- end -}}
{{- end -}}
{{- if ne $localPolicy "" -}}
  {{- $localPolicy -}}
{{- else if ne $globalPolicy "" -}}
  {{- $globalPolicy -}}
{{- else -}}
  {{- "IfNotPresent" -}}
{{- end -}}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "judge-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "judge-api.fullname" -}}
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
{{- define "judge-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "judge-api.labels" -}}
helm.sh/chart: {{ include "judge-api.chart" . }}
{{ include "judge-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "judge-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "judge-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
Configuration pattern: Supports global configuration via global.secrets.vault.serviceAccounts.judgeApi
Priority: local serviceAccount.name → global.secrets.vault.serviceAccounts.judgeApi → default
*/}}
{{- define "judge-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- $globalName := "" -}}
{{- if and .Values.global (hasKey .Values.global "secrets") -}}
  {{- if and .Values.global.secrets (hasKey .Values.global.secrets "vault") -}}
    {{- if and .Values.global.secrets.vault (hasKey .Values.global.secrets.vault "serviceAccounts") -}}
      {{- if hasKey .Values.global.secrets.vault.serviceAccounts "judgeApi" -}}
        {{- $globalName = .Values.global.secrets.vault.serviceAccounts.judgeApi -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $localName := .Values.serviceAccount.name | default "" -}}
{{- $defaultName := include "judge-api.fullname" . -}}
{{- coalesce $localName $globalName $defaultName -}}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for the connection string
Configuration pattern: Supports global configuration via global.secrets.manual.judgeApi
Priority: local sqlStore.secretName → global.secrets.manual.judgeApi.secretName → default
*/}}
{{- define "judge-api.connectionStringSecret.name" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default (include "judge-api.fullname" .) .Values.sqlStore.secretName }}
{{- else }}
{{- $globalName := "" -}}
{{- if and .Values.global (hasKey .Values.global "secrets") -}}
  {{- if and .Values.global.secrets (hasKey .Values.global.secrets "manual") -}}
    {{- if and .Values.global.secrets.manual (hasKey .Values.global.secrets.manual "judgeApi") -}}
      {{- if hasKey .Values.global.secrets.manual.judgeApi "secretName" -}}
        {{- $globalName = .Values.global.secrets.manual.judgeApi.secretName -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $localName := .Values.sqlStore.secretName | default "" -}}
{{- $defaultName := printf "%s-database" (include "judge-api.fullname" .) -}}
{{- coalesce $localName $globalName $defaultName -}}
{{- end }}
{{- end }}

{{/*
Create the key of the secret to use for the connection string
Configuration pattern: Supports global configuration via global.secrets.manual.judgeApi
Priority: global.secrets.manual.judgeApi.secretKey (if set) → local sqlStore.secretKey → default
*/}}
{{- define "judge-api.connectionStringSecret.key" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default "connectionstring" .Values.sqlStore.secretKey }}
{{- else }}
{{- if and .Values.global .Values.global.secrets .Values.global.secrets.manual .Values.global.secrets.manual.judgeApi .Values.global.secrets.manual.judgeApi.secretKey -}}
{{- .Values.global.secrets.manual.judgeApi.secretKey -}}
{{- else -}}
{{- .Values.sqlStore.secretKey | default "connectionString" -}}
{{- end -}}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for the connection string
*/}}
{{- define "judge-api.slackSecret.name" -}}
{{- if .Values.workflows.slackIntegration.createSecret }}
{{- default (printf "%s-slack" (include "judge-api.fullname" .)) .Values.workflows.slackIntegration.secretName }}
{{- else }}
{{- .Values.workflows.slackIntegration.secretName}}
{{- end }}
{{- end }}


{{/*
Create the key of the secret to use for the workflow slack channel id
*/}}
{{- define "judge-api.slackSecret.channelIdKey" -}}
{{- if .Values.workflows.slackIntegration.createSecret }}
{{- default "channelId" .Values.workflows.slackIntegration.channelIdKey }}
{{- else }}
{{- .Values.workflows.slackIntegration.channelIdKey }}
{{- end }}
{{- end }}

{{/*
Create the key of the secret to use for the workflow slack token 
*/}}
{{- define "judge-api.slackSecret.tokenKey" -}}
{{- if .Values.workflows.slackIntegration.createSecret }}
{{- default "token" .Values.workflows.slackIntegration.tokenKey }}
{{- else }}
{{- .Values.workflows.slackIntegration.tokenKey }}
{{- end }}
{{- end }}

{{/*
Image tag helper (fallback for standalone lint)
Returns the default image tag from global.version
*/}}
{{- define "judge.image.defaultTag" -}}
{{- if and .Values.global .Values.global.version -}}
{{ .Values.global.version }}
{{- else -}}
latest
{{- end -}}
{{- end -}}

{{/*
AWS IRSA Annotation Helper (fallback for standalone lint)
Auto-generates eks.amazonaws.com/role-arn annotation when IRSA is enabled
*/}}
{{- define "judge.aws.irsa.annotations" -}}
{{- $service := .service -}}
{{- $root := .root -}}
{{- if and $root.Values.global $root.Values.global.aws $root.Values.global.aws.irsa $root.Values.global.aws.irsa.enabled -}}
{{- $accountId := "" -}}
{{- if $root.Values.global.aws.accountId -}}
{{- $accountId = $root.Values.global.aws.accountId -}}
{{- else if and $root.Values.global.cloud $root.Values.global.cloud.aws $root.Values.global.cloud.aws.accountId -}}
{{- $accountId = $root.Values.global.cloud.aws.accountId -}}
{{- end -}}
{{- $prefix := $root.Values.global.aws.prefix | default "judge" -}}
eks.amazonaws.com/role-arn: arn:aws:iam::{{ $accountId }}:role/{{ $prefix }}-{{ $service }}
{{- end -}}
{{- end -}}

{{/*
Service URL helper for Kratos Admin (fallback for standalone lint)
*/}}
{{- define "judge.service.kratosAdminUrl" -}}
{{- $kratosName := "judge-kratos" -}}
{{- if hasKey .Values "kratos" -}}
  {{- if .Values.kratos -}}
    {{- $kratosName = default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s-admin.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}

{{/*
Service URL helper for Kratos Public (fallback for standalone lint)
*/}}
{{- define "judge.service.kratosPublicUrl" -}}
{{- $kratosName := "judge-kratos" -}}
{{- if hasKey .Values "kratos" -}}
  {{- if .Values.kratos -}}
    {{- $kratosName = default "judge-kratos" .Values.kratos.nameOverride -}}
  {{- end -}}
{{- end -}}
{{- printf "http://%s-%s-public.%s.svc.cluster.local" .Release.Name $kratosName .Release.Namespace -}}
{{- end -}}
