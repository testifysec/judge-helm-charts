{{/*
Render the imageRepository with the global and chart specific values.
*/}}
{{- define "judge-web.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride | trimPrefix "judge-" -}}
{{- if eq .Values.image.repository "" }}
{{- printf "%s/%s" .Values.image.registry $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" .Values.image.registry .Values.image.repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "judge-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "judge-web.fullname" -}}
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
{{- define "judge-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "judge-web.labels" -}}
helm.sh/chart: {{ include "judge-web.chart" . }}
{{ include "judge-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "judge-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "judge-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "judge-web.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "judge-web.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
