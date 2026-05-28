{{/* Standardized name <chart name>-<stage>-<component> */}}
{{- define "visit-counter.componentName" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- printf "%s-%s-%s" $context.Chart.Name $context.Values.global.stage $component | trunc 63 | trimSuffix "-" -}}
{{- end -}}
