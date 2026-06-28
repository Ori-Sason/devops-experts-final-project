{{/*
Standardized name <chart name>-<stage>-<component>
*/}}
{{- define "visit-counter.componentName" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- printf "%s-%s-%s" $context.Chart.Name $context.Values.global.stage $component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "visit-counter.labels" -}}
app.kubernetes.io/part-of: visit-counter
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.global.labels }}
{{- toYaml .Values.global.labels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "visit-counter.selectorLabels" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
app.kubernetes.io/name: {{ $component }}
app.kubernetes.io/instance: {{ $context.Release.Name }}
{{- end }}
