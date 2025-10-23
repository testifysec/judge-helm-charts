{{/*
ArgoCD Job Annotations Helper
Returns ArgoCD sync options annotation when global.argocd.enabled is true.
Required for proper Job management in ArgoCD (Jobs are immutable).
Usage: {{ include "judge.argocd.jobAnnotations" . | nindent 4 }}
Note: Duplicated from parent judge chart to allow standalone linting.
*/}}
{{- define "judge.argocd.jobAnnotations" -}}
{{- if and .Values.global (and .Values.global.argocd .Values.global.argocd.enabled) -}}
argocd.argoproj.io/sync-options: "Force=true,Replace=true"
{{- end -}}
{{- end -}}

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
Supports both new YAML format (from global.fulcio.issuers) and old JSON format (backward compat).
*/}}
{{- define "fulcio.configmap.contents" -}}
{{- if .Values.config.contents -}}
{{/* Backward compatibility: use config.contents if provided (JSON format) */}}
{{- toPrettyJson .Values.config.contents }}
{{- else if and .Values.global .Values.global.fulcio -}}
{{/* New YAML format from global.fulcio.issuers */}}
{{- $issuers := dict -}}
{{- $metaIssuers := dict -}}
{{- $ciMetadata := dict -}}
{{/* GitHub Actions issuer */}}
{{- if and .Values.global.fulcio.issuers.githubActions .Values.global.fulcio.issuers.githubActions.enabled -}}
{{- $gh := .Values.global.fulcio.issuers.githubActions -}}
{{- $ghIssuer := dict
  "issuer-url" $gh.issuerUrl
  "client-id" $gh.clientId
  "type" $gh.type
  "ci-provider" "github-workflow"
-}}
{{- $_ := set $issuers $gh.issuerUrl $ghIssuer -}}
{{/* GitHub workflow CI metadata */}}
{{- $ghWorkflow := dict
  "default-template-values" (dict "url" "https://github.com")
  "extension-templates" (dict
    "github-workflow-trigger" "event_name"
    "github-workflow-sha" "sha"
    "github-workflow-name" "workflow"
    "github-workflow-repository" "repository"
    "github-workflow-ref" "ref"
    "build-signer-uri" "{{ .url }}/{{ .job_workflow_ref }}"
    "build-signer-digest" "job_workflow_sha"
    "runner-environment" "runner_environment"
    "source-repository-uri" "{{ .url }}/{{ .repository }}"
    "source-repository-digest" "sha"
    "source-repository-ref" "ref"
    "source-repository-identifier" "repository_id"
    "source-repository-owner-uri" "{{ .url }}/{{ .repository_owner }}"
    "source-repository-owner-identifier" "repository_owner_id"
    "build-config-uri" "{{ .url }}/{{ .workflow_ref }}"
    "build-config-digest" "workflow_sha"
    "build-trigger" "event_name"
    "run-invocation-uri" "{{ .url }}/{{ .repository }}/actions/runs/{{ .run_id }}/attempts/{{ .run_attempt }}"
    "source-repository-visibility-at-signing" "repository_visibility"
  )
  "subject-alternative-name-template" "{{ .url }}/{{ .job_workflow_ref }}"
-}}
{{- $_ := set $ciMetadata "github-workflow" $ghWorkflow -}}
{{- end -}}
{{/* Kubernetes meta-issuer */}}
{{- if and .Values.global.fulcio.issuers.kubernetes .Values.global.fulcio.issuers.kubernetes.enabled -}}
{{- $k8s := .Values.global.fulcio.issuers.kubernetes -}}
{{- $k8sIssuer := dict
  "client-id" $k8s.clientId
  "type" "kubernetes"
-}}
{{- $_ := set $metaIssuers $k8s.metaPattern $k8sIssuer -}}
{{- end -}}
{{/* Build final config */}}
{{- $config := dict -}}
{{- if gt (len $issuers) 0 -}}
{{- $_ := set $config "oidc-issuers" $issuers -}}
{{- end -}}
{{- if gt (len $metaIssuers) 0 -}}
{{- $_ := set $config "meta-issuers" $metaIssuers -}}
{{- end -}}
{{- if gt (len $ciMetadata) 0 -}}
{{- $_ := set $config "ci-issuer-metadata" $ciMetadata -}}
{{- end -}}
{{- toYaml $config }}
{{- else -}}
{{/* Default: minimal Kubernetes issuer (YAML format) */}}
oidc-issuers:
  https://kubernetes.default.svc:
    issuer-url: https://kubernetes.default.svc
    client-id: sigstore
    type: kubernetes
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

{{/*
PKI Secret Name - Returns the appropriate secret name based on global.pki.mode
Usage: {{ include "fulcio.pkiSecretName" . }}
*/}}
{{- define "fulcio.pkiSecretName" -}}
{{- if and .Values.global .Values.global.pki (eq .Values.global.pki.mode "vault") -}}
{{- printf "%s-pki" (include "fulcio.fullname" .) -}}
{{- else -}}
{{- .Values.server.secret | default "fulcio-server-secret" -}}
{{- end -}}
{{- end -}}

{{/*
PKI Mode Check - Returns true if createcerts should be enabled (dev mode)
Usage: {{ include "fulcio.createcertsEnabled" . }}
*/}}
{{- define "fulcio.createcertsEnabled" -}}
{{- if and .Values.global .Values.global.pki -}}
{{- eq .Values.global.pki.mode "dev" -}}
{{- else -}}
{{- .Values.createcerts.enabled | default true -}}
{{- end -}}
{{- end -}}
