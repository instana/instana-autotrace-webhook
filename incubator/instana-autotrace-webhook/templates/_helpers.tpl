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
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
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