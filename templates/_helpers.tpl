# {{- define "mi-mpi.replicas2" -}}
# {{- if eq .Values.namespace "dev" }}
# replicas: 2 
# {{- else if eq .Values.namespace "prod" }}
# replicas: 10
# {{- else }}
# replicas: {{ .Values.replicaCount }}
# {{- end }}
# {{- end }}

{{- define "mi-mpi.numberReplicas" -}}
    {{- if .Values.replicaCount -}}
        {{ .Values.replicaCount }}
    {{- else if eq .Values.namespace "dev" -}}
        2
    {{- else if eq .Values.namespace "prod" -}}
        10
    {{- else -}}
        4
    {{- end -}}
{{- end -}}