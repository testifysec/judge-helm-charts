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
*/}}
{{- define "judge-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "judge-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for the connection string
*/}}
{{- define "judge-api.connectionStringSecret.name" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default (include "judge-api.fullname" .) .Values.sqlStore.secretName }}
{{- else }}
{{- .Values.sqlStore.secretName }}
{{- end }}
{{- end }}

{{/*
Create the key of the secret to use for the connection string
*/}}
{{- define "judge-api.connectionStringSecret.key" -}}
{{- if .Values.sqlStore.createSecret }}
{{- default "connectionstring" .Values.sqlStore.secretKey }}
{{- else }}
{{- .Values.sqlStore.secretKey }}
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
