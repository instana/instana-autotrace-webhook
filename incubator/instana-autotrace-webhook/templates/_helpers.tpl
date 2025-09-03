{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "instana-autotrace-webhook.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "instana-autotrace-webhook.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "instana-autotrace-webhook.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "instana-autotrace-webhook.tlsSecretName" -}}
{{- printf "%s-serving-tls" (include "instana-autotrace-webhook.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "instana-autotrace-webhook.caSecretName" -}}
{{- printf "%s-ca" (include "instana-autotrace-webhook.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Add Helm metadata to resource labels.
*/}}
{{- define "instana-autotrace-webhook.commonLabels" -}}
app.kubernetes.io/name: {{ include "instana-autotrace-webhook.name" . }}
{{ if .Values.templating -}}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- else -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "instana-autotrace-webhook.chart" . }}
{{- end -}}
{{- end -}}

{{- define "instana-autotrace-webhook.webhook.imagePullSecret" }}
{{- if not .Values.webhook.imagePullCredentials.registry }}
{{- fail "The 'webhook.imagePullCredentials.registry' setting must be provided" }}
{{- end }}
{{- if not .Values.webhook.imagePullCredentials.username }}
{{- fail "The 'webhook.imagePullCredentials.username' setting must be provided" }}
{{- end }}
{{- if and (not .Values.webhook.imagePullCredentials.password) (eq (len .Values.webhook.imagePullSecrets) 0)}}
{{- fail "The 'webhook.imagePullCredentials.password' or 'webhook.imagePullSecrets' setting must be provided" }}
{{- end }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .Values.webhook.imagePullCredentials.registry .Values.webhook.imagePullCredentials.username .Values.webhook.imagePullCredentials.password (printf "%s:%s" .Values.webhook.imagePullCredentials.username .Values.webhook.imagePullCredentials.password | b64enc) | b64enc }}
{{- end }}

{{- define "instana-autotrace-webhook.init.imagePullSecret" }}
{{- if and (and .Values.autotrace.instrumentation.imagePullCredentials.username .Values.autotrace.instrumentation.imagePullCredentials.password) .Values.autotrace.instrumentation.imagePullCredentials.registry }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .Values.autotrace.instrumentation.imagePullCredentials.registry .Values.autotrace.instrumentation.imagePullCredentials.username .Values.autotrace.instrumentation.imagePullCredentials.password (printf "%s:%s" .Values.autotrace.instrumentation.imagePullCredentials.username .Values.autotrace.instrumentation.imagePullCredentials.password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{- define "k8s-admission-controller-api-version" }}
{{- if .Capabilities.APIVersions.Has "admissionregistration.k8s.io/v1" }}
{{- printf "v1" }}
{{- else }}
{{- printf "v1beta1" }}
{{- end }}
{{- end }}

{{- define "admission-controller-api-versions" }}
{{- if .Capabilities.APIVersions.Has "admissionregistration.k8s.io/v1" }}
- v1
{{- end }}
{{- if .Capabilities.APIVersions.Has "admissionregistration.k8s.io/v1beta1" }}
- v1beta1
{{- end }}
{{- end }}

{{- define "is_openshift" }}
{{- .Capabilities.APIVersions.Has "apps.openshift.io/v1" }}
{{- end }}

{{/*
The name of the PodSecurityPolicy used.
*/}}
{{- define "instana-autotrace-webhook.podSecurityPolicyName" -}}
{{- if .Values.rbac.psp.enabled -}}
{{ default (include "instana-autotrace-webhook.fullname" .) .Values.rbac.psp.name }}
{{- end -}}
{{- end -}}

{{- define "kubeVersion" -}}
{{- if (regexMatch "\\d+\\.\\d+\\.\\d+-(?:eks|gke).+" .Capabilities.KubeVersion.Version) -}}
  {{- regexFind "\\d+\\.\\d+\\.\\d+" .Capabilities.KubeVersion.Version -}}
{{- else -}}
  {{- printf .Capabilities.KubeVersion.Version }}
{{- end -}}
{{- end -}}

{{/*
The full webhook image with the version
Global tag is always respected, then the old way of setting the version within the image
Otherwise, default to the current version of the webhook
*/}}
{{- define "instana-autotrace-webhook.image" -}}
{{- $repo := index .Values.webhook "image" -}}

{{/* Get the image name (last part after final slash) */}}
{{- $imageName := regexFind "[^/]+$" $repo -}}

{{/* Get everything before the image name (registry + path) */}}
{{- $registryPath := trimSuffix $imageName $repo -}}

{{/* Check if the image name has a tag or digest */}}
{{- $hasTagOrDigest := or (contains ":" $imageName) (contains "@" $imageName) -}}

{{/* Remove any existing tag from the image name */}}
{{- $imageNameWithoutTag := regexReplaceAll "[:@].*$" $imageName "" -}}

{{- if .Values.global.version -}}
  {{/* Use global version */}}
  {{- printf "%s%s:%s" $registryPath $imageNameWithoutTag .Values.global.version -}}
{{- else if $hasTagOrDigest -}}
  {{/* Keep the original repo with its tag/digest */}}
  {{- $repo | trim -}}
{{- else -}}
  {{/* Use Chart.AppVersion as tag */}}
  {{- printf "%s%s:%s" $registryPath $imageNameWithoutTag .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/*
The full instrumentation image with the version
Global tag is always respected, then the old way of setting the version within the image
Otherwise, default to the current version of the webhook
*/}}
{{- define "instrumentation.image" -}}
{{- $repo := index .Values.autotrace.instrumentation "image" -}}

{{/* Get the image name (last part after final slash) */}}
{{- $imageName := regexFind "[^/]+$" $repo -}}

{{/* Get everything before the image name (registry + path) */}}
{{- $registryPath := trimSuffix $imageName $repo -}}

{{/* Check if the image name has a tag or digest */}}
{{- $hasTagOrDigest := or (contains ":" $imageName) (contains "@" $imageName) -}}

{{/* Remove any existing tag from the image name */}}
{{- $imageNameWithoutTag := regexReplaceAll "[:@].*$" $imageName "" -}}

{{- if .Values.global.version -}}
  {{/* Use global version */}}
  {{- printf "%s%s:%s" $registryPath $imageNameWithoutTag .Values.global.version -}}
{{- else if $hasTagOrDigest -}}
  {{/* Keep the original repo with its tag/digest */}}
  {{- $repo | trim -}}
{{- else -}}
  {{/* Use Chart.AppVersion as tag */}}
  {{- printf "%s%s:%s" $registryPath $imageNameWithoutTag .Chart.AppVersion -}}
{{- end -}}
{{- end -}}