{{/*
Render the imageRepository with the global and chart specific values.
*/}}
{{- define "judge.image.repository" -}}
{{- $chartName := default .Chart.Name .Values.nameOverride }}
{{- $registryUrl := coalesce ((.Values.image).registry) ((.Values.global).registry.url | default "") "ghcr.io" }}
{{- $repository := coalesce ((.Values.image).repository) ((.Values.global).registry.repository | default "") }}
{{- if eq $repository "" }}
{{- printf "%s/%s" $registryUrl $chartName | trimSuffix "/" -}}
{{- else }}
{{- printf "%s/%s/%s" $registryUrl $repository $chartName | trimSuffix "/" -}}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "tsa.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tsa.fullname" -}}
{{- if .Values.server.fullnameOverride -}}
{{- .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define the raw tsa.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "tsa.rawnamespace" -}}
{{- if .Values.forceNamespace -}}
{{ print .Values.forceNamespace }}
{{- else -}}
{{ print .Release.Namespace }}
{{- end -}}
{{- end -}}

{{/*
Define the tsa.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "tsa.namespace" -}}
{{ printf "namespace: %s" (include "tsa.rawnamespace" .) }}
{{- end -}}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tsa.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tsa.labels" -}}
helm.sh/chart: {{ include "tsa.chart" . }}
{{ include "tsa.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tsa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tsa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tsa.serviceAccountName" -}}
{{- if .Values.server.serviceAccount.create }}
{{- default (include "tsa.fullname" .) .Values.server.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.server.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image path for the passed in image field
*/}}
{{- define "tsa.image" -}}
{{- if eq (substr 0 7 .version) "sha256:" -}}
{{- printf "%s/%s@%s" .registry .repository .version -}}
{{- else -}}
{{- printf "%s/%s:%s" .registry .repository .version -}}
{{- end -}}
{{- end -}}

{{/*
Create Container Ports based on Service Ports
*/}}
{{- define "tsa.containerPorts" -}}
{{- range . }}
- containerPort: {{ (ternary .port .targetPort (empty .targetPort)) | int }}
  protocol: {{ default "TCP" .protocol }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the config
*/}}
{{- define "tsa.config" -}}
{{ printf "%s-config" (include "tsa.fullname" .) }}
{{- end }}

{{/*
Return the appropriate apiVersion for ingress.
*/}}
{{- define "tsa.server.ingress.backend" -}}
{{- $root := index . 0 -}}
{{- $local := index . 1 -}}
{{- $servicePort := index . 2 -}}
service:
  name: {{ (default (include "tsa.fullname" $root) $local.service_name) }}
  port:
    number: {{ $servicePort | int }}
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
