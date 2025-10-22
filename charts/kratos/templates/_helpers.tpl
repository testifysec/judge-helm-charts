{{/* vim: set filetype=mustache: */}}

{{/*
Render the imageRepository with the global and chart specific values.
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- if eq .Values.image.repository "" }}
{{- printf "%s/%s" .Values.image.registry $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" .Values.image.registry .Values.image.repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "kratos.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kratos.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a secret name which can be overridden.
*/}}
{{- define "kratos.secretname" -}}
{{- if .Values.secret.nameOverride -}}
{{- .Values.secret.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{ include "kratos.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kratos.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate the dsn value
*/}}
{{- define "kratos.dsn" -}}
{{- .Values.kratos.config.dsn }}
{{- end -}}

{{/*
Generate the secrets.default value
*/}}
{{- define "kratos.secrets.default" -}}
  {{- if (.Values.kratos.config.secrets).default -}}
    {{- if kindIs "slice" .Values.kratos.config.secrets.default -}}
      {{- if gt (len .Values.kratos.config.secrets.default) 1 -}}
        "{{- join "\",\"" .Values.kratos.config.secrets.default -}}"
      {{- else -}}
        {{- join "" .Values.kratos.config.secrets.default -}}
      {{- end -}}
    {{- else -}}
      {{- fail "Expected kratos.config.secrets.default to be a list of strings" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Generate the secrets.cookie value
*/}}
{{- define "kratos.secrets.cookie" -}}
  {{- if (.Values.kratos.config.secrets).cookie -}}
    {{- if kindIs "slice" .Values.kratos.config.secrets.cookie -}}
      {{- if gt (len .Values.kratos.config.secrets.cookie) 1 -}}
        "{{- join "\",\"" .Values.kratos.config.secrets.cookie -}}"
      {{- else -}}
        {{- join "" .Values.kratos.config.secrets.cookie -}}
      {{- end -}}
    {{- else -}}
      {{- fail "Expected kratos.config.secrets.cookie to be a list of strings" -}}
    {{- end -}}
  {{- end -}}  
{{- end -}}

{{/*
Generate the secrets.cipher value
*/}}
{{- define "kratos.secrets.cipher" -}}
  {{- if (.Values.kratos.config.secrets).cipher -}}
    {{- if kindIs "slice" .Values.kratos.config.secrets.cipher -}}
      {{- if gt (len .Values.kratos.config.secrets.cipher) 1 -}}
        "{{- join "\",\"" .Values.kratos.config.secrets.cipher -}}"
      {{- else -}}
        {{- join "" .Values.kratos.config.secrets.cipher -}}
      {{- end -}}
    {{- else -}}
      {{- fail "Expected kratos.config.secrets.cipher to be a list of strings" -}}
    {{- end -}}
  {{- end -}}  
{{- end -}}


{{/*
Generate the configmap data, redacting secrets
*/}}
{{- define "kratos.configmap" -}}
{{- $config := omit .Values.kratos.config "dsn" "secrets" | deepCopy -}}
{{- if $config.courier.smtp.connection_uri -}}
{{- $config = set $config "courier" (set $config.courier "smtp" (omit $config.courier.smtp "connection_uri")) -}}
{{- end -}}
{{- tpl (toYaml $config) . -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "kratos.labels" -}}
app.kubernetes.io/name: {{ include "kratos.name" . }}
helm.sh/chart: {{ include "kratos.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if $.Values.watcher.enabled }}
{{ printf "\"%s\": \"%s\"" $.Values.watcher.watchLabelKey (include "kratos.name" .) }}
{{- end }}
{{- end -}}

{{/*
Generate image
*/}}
{{- define "kratos.image" -}}
{{- if eq "string" ( typeOf .Values.image ) }}
{{- printf "%s" .Values.image -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
Generate imagePullPolicy
*/}}
{{- define "kratos.imagePullPolicy" -}}
{{- if eq "string" ( typeOf .Values.image ) }}
{{- printf "%s" .Values.imagePullPolicy -}}
{{- else -}}
{{- printf "%s" .Values.image.pullPolicy -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
Helm golf: Supports global configuration via global.secrets.vault.serviceAccounts.kratos
Priority: local deployment.serviceAccount.name → global.secrets.vault.serviceAccounts.kratos → default
*/}}
{{- define "kratos.serviceAccountName" -}}
{{- if .Values.deployment.serviceAccount.create }}
{{- $globalName := "" -}}
{{- if and .Values.global (hasKey .Values.global "secrets") -}}
  {{- if and .Values.global.secrets (hasKey .Values.global.secrets "vault") -}}
    {{- if and .Values.global.secrets.vault (hasKey .Values.global.secrets.vault "serviceAccounts") -}}
      {{- if hasKey .Values.global.secrets.vault.serviceAccounts "kratos" -}}
        {{- $globalName = .Values.global.secrets.vault.serviceAccounts.kratos -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $localName := .Values.deployment.serviceAccount.name | default "" -}}
{{- $defaultName := include "kratos.fullname" . -}}
{{- coalesce $localName $globalName $defaultName -}}
{{- else }}
{{- default "default" .Values.deployment.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account for the Job to use
*/}}
{{- define "kratos.job.serviceAccountName" -}}
{{- if .Values.job.serviceAccount.create }}
{{- printf "%s-job" (default (include "kratos.fullname" .) .Values.job.serviceAccount.name) }}
{{- else }}
{{- include "kratos.serviceAccountName" . }}
{{- end }}
{{- end }}

{{/*
Checksum annotations generated from configmaps and secrets
*/}}
{{- define "kratos.annotations.checksum" -}}
{{- if .Values.configmap.hashSumEnabled }}
checksum/kratos-config: {{ include (print $.Template.BasePath "/configmap-config.yaml") . | sha256sum }}
checksum/kratos-templates: {{ include (print $.Template.BasePath "/configmap-templates.yaml") . | sha256sum }}
{{- end }}
{{- if and .Values.secret.enabled .Values.secret.hashSumEnabled }}
checksum/kratos-secrets: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
{{- end }}
{{- end }}

{{/*
Check the migration type value and fail if unexpected 
*/}}
{{- define "kratos.automigration.typeVerification" -}}
{{- if and .Values.kratos.automigration.enabled  .Values.kratos.automigration.type }}
  {{- if and (ne .Values.kratos.automigration.type "initContainer") (ne .Values.kratos.automigration.type "job") }}
    {{- fail "kratos.automigration.type must be either 'initContainer' or 'job'" -}}
  {{- end }}  
{{- end }}
{{- end }}

{{/*
Common labels for the cleanup cron job
*/}}
{{- define "kratos.cleanup.labels" -}}
"app.kubernetes.io/name": {{ printf "%s-cleanup" (include "kratos.name" .) | quote }}
"app.kubernetes.io/instance": {{ .Release.Name | quote }}
{{- if .Chart.AppVersion }}
"app.kubernetes.io/version": {{ .Chart.AppVersion | quote }}
{{- end }}
"app.kubernetes.io/managed-by": {{ .Release.Service | quote }}
"app.kubernetes.io/component": cleanup
"helm.sh/chart": {{ include "kratos.chart" . | quote }}
{{- end -}}

{{/*
Database Endpoint Helper for Kratos (fallback for standalone lint)
Returns PostgreSQL DSN for dev mode or RDS DSN for production
*/}}
{{- define "judge.database.endpoint.kratos" -}}
{{- $mode := "aws" -}}
{{- if and .Values.global .Values.global.mode -}}
{{- $mode = .Values.global.mode -}}
{{- else if and .Values.global .Values.global.dev -}}
{{- $mode = "dev" -}}
{{- end -}}
{{- if eq $mode "dev" -}}
{{- $username := "judge" -}}
{{- $password := "dev-preview-password" -}}
{{- if and .Values.global .Values.global.devDatabase -}}
{{- $username = .Values.global.devDatabase.username | default "judge" -}}
{{- $password = .Values.global.devDatabase.password | default "dev-preview-password" -}}
{{- end -}}
postgres://{{ $username }}:{{ $password }}@{{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local:5432/kratos?sslmode=disable
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
