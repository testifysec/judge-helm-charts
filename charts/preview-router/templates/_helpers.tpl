{{/*
Create a default fully qualified app name.
*/}}
{{- define "preview-router.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "preview-router.labels" -}}
app.kubernetes.io/name: preview-router
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "preview-router.selectorLabels" -}}
app.kubernetes.io/name: preview-router
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}