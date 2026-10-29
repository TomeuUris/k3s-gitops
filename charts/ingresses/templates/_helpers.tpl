{{- define "kubecluster-ingresses.serviceRoute" -}}
{{- if .config.enabled }}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .name }}
  namespace: {{ .config.namespace }}
  annotations:
    kubernetes.io/ingress.class: {{ .root.Values.ingressClass }}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`{{ .config.host }}.{{ .root.Values.baseUri }}`)
      kind: Rule
      services:
        - name: {{ .config.service }}
          port: {{ .config.port }}
  tls: {}
{{- end }}
{{- end }}

{{- define "kubecluster-ingresses.externalRoute" -}}
{{- if .config.enabled }}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .name }}
  namespace: {{ .config.namespace }}
  annotations:
    kubernetes.io/ingress.class: {{ .root.Values.ingressClass }}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`{{ .config.host }}.{{ .root.Values.baseUri }}`)
      kind: Rule
      services:
        - name: {{ .config.service }}
          port: {{ .config.port }}
{{- with .config.middleware }}
      middlewares:
        - name: {{ .name }}
          namespace: {{ .namespace }}
{{- end }}
  tls: {}
{{- end }}
{{- end }}
