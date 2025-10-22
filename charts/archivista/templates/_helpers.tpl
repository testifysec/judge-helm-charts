{{/*
Render the imageRepository with the global and chart specific values.
Precedence: .Values.image.repository (if non-empty) → .Values.global.registry.repository → ""
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- $registryUrl := coalesce ((.Values.image).registry) ((.Values.global).registry.url | default "") "ghcr.io" }}
{{- $localRepo := ((.Values.image).repository) | default "" }}
{{- $globalRepo := ((.Values.global).registry.repository) | default "" }}
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
{{- define "archivista.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "archivista.fullname" -}}
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
{{- define "archivista.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "archivista.labels" -}}
helm.sh/chart: {{ include "archivista.chart" . }}
{{ include "archivista.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "archivista.selectorLabels" -}}
app.kubernetes.io/name: {{ include "archivista.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
Helm golf: Supports global configuration via global.secrets.vault.serviceAccounts.archivista
Priority: local serviceAccount.name → global.secrets.vault.serviceAccounts.archivista → default
*/}}
{{- define "archivista.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- $globalName := "" -}}
{{- if and .Values.global (hasKey .Values.global "secrets") -}}
  {{- if and .Values.global.secrets (hasKey .Values.global.secrets "vault") -}}
    {{- if and .Values.global.secrets.vault (hasKey .Values.global.secrets.vault "serviceAccounts") -}}
      {{- if hasKey .Values.global.secrets.vault.serviceAccounts "archivista" -}}
        {{- $globalName = .Values.global.secrets.vault.serviceAccounts.archivista -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $localName := .Values.serviceAccount.name | default "" -}}
{{- $defaultName := include "archivista.fullname" . -}}
{{- coalesce $localName $globalName $defaultName -}}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for the connection string
*/}}
{{- define "archivista.connectionStringSecret.name" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default (include "archivista.fullname" .) .Values.sqlStore.secretName }}
{{- else }}
{{- default (printf "%s-database" (include "archivista.fullname" .)) .Values.sqlStore.secretName }}
{{- end }}
{{- end }}
{{/*
Create the key of the secret to use for the connection string
*/}}
{{- define "archivista.connectionStringSecret.key" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default "connectionstring" .Values.sqlStore.secretKey }}
{{- else }}
{{- .Values.sqlStore.secretKey }}
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
Service URL helper for Gateway (fallback for standalone lint)
*/}}
{{- define "judge.service.gatewayUrl" -}}
{{- printf "http://%s-judge-gateway.%s.svc.cluster.local:4000" .Release.Name .Release.Namespace -}}
{{- end -}}
