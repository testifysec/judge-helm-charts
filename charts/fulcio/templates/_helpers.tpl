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
{{- define "fulcio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fulcio.fullname" -}}
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
Define the raw fulcio.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "fulcio.rawnamespace" -}}
{{- if .Values.forceNamespace -}}
{{ print .Values.forceNamespace }}
{{- else -}}
{{ print .Release.Namespace }}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified createcerts name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fulcio.createcerts.fullname" -}}
{{- if .Values.createcerts.fullnameOverride -}}
{{- .Values.createcerts.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.createcerts.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.createcerts.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define the fulcio.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "fulcio.namespace" -}}
{{ printf "namespace: %s" (include "fulcio.rawnamespace" .) }}
{{- end -}}

{{/*
Create the name of the service account to use for the createcerts component
*/}}
{{- define "fulcio.serviceAccountName.createcerts" -}}
{{- if .Values.createcerts.serviceAccount.create -}}
    {{ default (include "fulcio.createcerts.fullname" .) .Values.createcerts.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.createcerts.serviceAccount.name }}
{{- end -}}
{{- end -}}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fulcio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fulcio.labels" -}}
helm.sh/chart: {{ include "fulcio.chart" . }}
{{ include "fulcio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fulcio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fulcio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "fulcio.serviceAccountName" -}}
{{- if .Values.server.serviceAccount.create }}
{{- default (include "fulcio.fullname" .) .Values.server.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.server.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image path for the passed in image field
*/}}
{{- define "fulcio.image" -}}
{{- if eq (substr 0 7 .version) "sha256:" -}}
{{- printf "%s/%s@%s" .registry .repository .version -}}
{{- else -}}
{{- printf "%s/%s:%s" .registry .repository .version -}}
{{- end -}}
{{- end -}}

{{/*
Create Container Ports based on Service Ports
*/}}
{{- define "fulcio.containerPorts" -}}
{{- range . }}
- containerPort: {{ (ternary .port .targetPort (empty .targetPort)) | int }}
  protocol: {{ default "TCP" .protocol }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the config
*/}}
{{- define "fulcio.config" -}}
{{ printf "%s-config" (include "fulcio.fullname" .) }}
{{- end }}

{{/*
Return the appropriate apiVersion for ingress.
*/}}
{{- define "fulcio.server.ingress.backend" -}}
{{- $root := index . 0 -}}
{{- $local := index . 1 -}}
{{- $servicePort := index . 2 -}}
service:
  name: {{ (default (include "fulcio.fullname" $root) $local.service_name) }}
  port:
    number: {{ $servicePort | int }}
{{- end -}}

{{/*
Return the contents for fulcio config.
*/}}
{{- define "fulcio.configmap.contents" -}}
{{- if .Values.config.contents -}}
{{- toPrettyJson .Values.config.contents }}
{{- else -}}
{
  "OIDCIssuers": {
    "https://kubernetes.default.svc": {
      "IssuerURL": "https://kubernetes.default.svc",
      "ClientID": "sigstore",
      "Type": "kubernetes"
    }
  },
  "MetaIssuers": {
    "https://kubernetes.*.svc": {
      "ClientID": "sigstore",
      "Type": "kubernetes"
    }
  }
}
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
