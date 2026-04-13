{{/*
  _helpers.tpl — Shared Helm template helpers for the osm-arc chart.
  
  These labels are applied to all Arc-specific resources (metrics agent, RBAC, etc.)
  to enable consistent identification and Kubernetes resource management.
*/}}

{{/* Labels to be added to all resources */}}
{{- define "osm.arcLabels" -}}
app.kubernetes.io/name: openservicemesh.io
app.kubernetes.io/instance: {{ .Values.osm.osm.meshName }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}
