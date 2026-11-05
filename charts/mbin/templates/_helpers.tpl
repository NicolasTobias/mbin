{{- define "mbin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mbin.fullname" -}}
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

{{- define "mbin.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "mbin.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mbin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mbin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mbin.image" -}}
{{- printf "%s:%s" .Values.image.repository (default (printf "v%s" .Chart.AppVersion) .Values.image.tag) -}}
{{- end -}}

{{- define "mbin.secretName" -}}
{{- default (include "mbin.fullname" .) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "mbin.oauthEnabled" -}}
{{- if or .Values.oauth.existingSecret (and .Values.oauth.privateKey .Values.oauth.publicKey) -}}true{{- end -}}
{{- end -}}

{{- define "mbin.oauthSecretName" -}}
{{- default (printf "%s-oauth" (include "mbin.fullname" .)) .Values.oauth.existingSecret -}}
{{- end -}}

{{- define "mbin.postgresHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" (include "mbin.fullname" .) -}}
{{- else -}}
{{- required "postgresql.external.host is required when postgresql.enabled=false" .Values.postgresql.external.host -}}
{{- end -}}
{{- end -}}

{{- define "mbin.postgresPort" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{ .Values.postgresql.external.port }}{{- end -}}
{{- end -}}

{{/*
Environment shared by the web and messenger pods. Connection strings are built
here from the raw passwords so that an existing Secret only has to hold the
passwords, never full URLs. Order matters: $(VAR) can only reference variables
declared above it.
*/}}
{{- define "mbin.env" -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mbin.secretName" . }}
      key: POSTGRES_PASSWORD
- name: DATABASE_URL
  value: "postgresql://{{ .Values.postgresql.auth.username }}:$(POSTGRES_PASSWORD)@{{ include "mbin.postgresHost" . }}:{{ include "mbin.postgresPort" . }}/{{ .Values.postgresql.auth.database }}?serverVersion={{ .Values.postgresql.version }}&charset=utf8"
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mbin.secretName" . }}
      key: RABBITMQ_PASSWORD
- name: MESSENGER_TRANSPORT_DSN
  value: "amqp://{{ .Values.rabbitmq.auth.username }}:$(RABBITMQ_PASSWORD)@{{ include "mbin.fullname" . }}-amqproxy:5673/%2f/messages"
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mbin.secretName" . }}
      key: REDIS_PASSWORD
- name: REDIS_DNS
  value: "redis://$(REDIS_PASSWORD)@{{ include "mbin.fullname" . }}-valkey:6379"
{{- if include "mbin.oauthEnabled" . }}
- name: OAUTH_PASSPHRASE
  valueFrom:
    secretKeyRef:
      name: {{ include "mbin.oauthSecretName" . }}
      key: passphrase
      optional: true
{{- end }}
{{- end -}}
