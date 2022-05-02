{{/* Labels to be added to all resources */}}
{{- define "osm.arcLabels" -}}
app.kubernetes.io/name: openservicemesh.io
app.kubernetes.io/instance: {{ .Values.osm.osm.meshName }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}
