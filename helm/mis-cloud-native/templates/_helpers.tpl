{{- define "mis-cloud-native.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mis-cloud-native.fullname" -}}
{{- $name := .Chart.Name -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.nameOverride -}}
{{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mis-cloud-native.labels" -}}
app.kubernetes.io/name: {{ include "mis-cloud-native.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "mis-cloud-native.serviceLabels" -}}
{{ include "mis-cloud-native.labels" . }}
{{- end -}}

{{- define "mis-cloud-native.image" -}}
{{- $global := .global -}}
{{- $image := .image -}}
{{- if $global.imageRegistry -}}
{{- if contains "$GHCR_OWNER" $image -}}
{{- $ghcrOwner := $global.ghcrOwner | default "kayis-rahman" -}}
{{- $processedImage := $image | replace "$GHCR_OWNER" $ghcrOwner -}}
{{- printf "%s/%s" $global.imageRegistry $processedImage -}}
{{- else -}}
{{- printf "%s/%s" $global.imageRegistry $image -}}
{{- end -}}
{{- else -}}
{{- if contains "$GHCR_OWNER" $image -}}
{{- $ghcrOwner := $global.ghcrOwner | default "kayis-rahman" -}}
{{- $image | replace "$GHCR_OWNER" $ghcrOwner -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}
{{- end -}}
