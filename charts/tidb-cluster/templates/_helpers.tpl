{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "tidb-cluster.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "helm-toolkit.utils.template" -}}
{{- $name := index . 0 -}}
{{- $context := index . 1 -}}
{{- $last := base $context.Template.Name }}
{{- $wtf := $context.Template.Name | replace $last $name -}}
{{ include $wtf $context }}
{{- end -}}

{{- define "cluster.name" -}}
{{- default .Release.Name .Values.clusterName }}
{{- end -}}

{{- define "cluster.scheme" -}}
{{ if and .Values.tlsCluster .Values.tlsCluster.enabled  }}https{{ else }}http{{ end }}
{{- end -}}

{{/*
Encapsulate PD configmap data for consistent digest calculation
*/}}
{{- define "pd-configmap.data" -}}
startup-script: |-
{{ tuple "scripts/_start_pd.sh.tpl" . | include "helm-toolkit.utils.template" | indent 2 }}
config-file: |-
    {{- if .Values.pd.config }}
{{ .Values.pd.config | indent 2 }}
    {{- end -}}
    {{- if and .Values.tlsCluster .Values.tlsCluster.enabled }}
  [security]
  cacert-path = "/var/lib/pd-tls/ca.crt"
  cert-path = "/var/lib/pd-tls/tls.crt"
  key-path = "/var/lib/pd-tls/tls.key"
    {{- end -}}

{{- end -}}

{{- define "pd-configmap.data-digest" -}}
{{ include "pd-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{/*
Encapsulate TiKV configmap data for consistent digest calculation
*/}}
{{- define "tikv-configmap.data" -}}
startup-script: |-
{{ tuple "scripts/_start_tikv.sh.tpl" . | include "helm-toolkit.utils.template" | indent 2 }}
config-file: |-
    {{- if .Values.tikv.config }}
{{ .Values.tikv.config | indent 2 }}
    {{- end -}}
    {{- if and .Values.tlsCluster .Values.tlsCluster.enabled }}
  [security]
  ca-path = "/var/lib/tikv-tls/ca.crt"
  cert-path = "/var/lib/tikv-tls/tls.crt"
  key-path = "/var/lib/tikv-tls/tls.key"
    {{- end -}}

{{- end -}}

{{- define "tikv-configmap.data-digest" -}}
{{ include "tikv-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{- define "tidb-configmap.data.init-sql" -}}
  {{- if (and .Values.tidb.auth.enabled .Values.tidb.auth.database) }}
  CREATE DATABASE IF NOT EXISTS {{ .Values.tidb.auth.database }};
  {{- if .Values.tidb.auth.username }}
  GRANT ALL PRIVILEGES ON {{ .Values.tidb.auth.database }}.* TO '{{ .Values.tidb.auth.username }}'@'%';
  {{- end -}}
  {{- end -}}
  {{- if .Values.tidb.initSql }}
{{ .Values.tidb.initSql | indent 2 -}}
  {{- end -}}
{{- end -}}

{{/*
Encapsulate TiDB configmap data for consistent digest calculation
*/}}
{{- define "tidb-configmap.data" -}}
startup-script: |-
{{ tuple "scripts/_start_tidb.sh.tpl" . | include "helm-toolkit.utils.template" | indent 2 }}
  {{- if (or .Values.tidb.initSql (and .Values.tidb.auth.enabled .Values.tidb.auth.database)) }}
init-sql: |-
  {{- include "tidb-configmap.data.init-sql" . }}
  {{- end }}
config-file: |-
    {{- if .Values.tidb.config }}
{{ .Values.tidb.config | indent 2 }}
    {{- end -}}
    {{- if or (and .Values.tlsCluster .Values.tlsCluster.enabled) (and .Values.tidb.tlsClient .Values.tidb.tlsClient.enabled) }}
  [security]
    {{- end -}}
    {{- if and .Values.tlsCluster .Values.tlsCluster.enabled }}
  cluster-ssl-ca = "/var/lib/tidb-tls/ca.crt"
  cluster-ssl-cert = "/var/lib/tidb-tls/tls.crt"
  cluster-ssl-key = "/var/lib/tidb-tls/tls.key"
    {{- end -}}
    {{- if and .Values.tidb.tlsClient .Values.tidb.tlsClient.enabled }}
  ssl-ca = "/var/lib/tidb-server-tls/ca.crt"
  ssl-cert = "/var/lib/tidb-server-tls/tls.crt"
  ssl-key = "/var/lib/tidb-server-tls/tls.key"
    {{- end -}}

{{- end -}}

{{- define "tidb-configmap.data-digest" -}}
{{ include "tidb-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{/*
Encapsulate pump configmap data for consistent digest calculation
*/}}
{{- define "pump.tlsSecretName" -}}
{{ .Values.clusterName }}-pump
{{- end -}}

{{- define "pump-configmap.data" -}}
pump-config: |-
    {{- if .Values.binlog.pump.config }}
{{ .Values.binlog.pump.config | indent 2 }}
    {{- if and .Values.tlsCluster .Values.tlsCluster.enabled }}
  [security]
  ssl-ca = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  ssl-cert = "/var/lib/pump-tls/tls.crt"
  ssl-key = "/var/lib/pump-tls/tls.key"
    {{- end -}}
    {{- else -}}
{{ tuple "config/_pump-config.tpl" . | include "helm-toolkit.utils.template" | indent 2 }}
    {{- end -}}
{{- end -}}

{{- define "pump-configmap.data-digest" -}}
{{ include "pump-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{/*
Encapsulate drainer configmap data for consistent digest calculation
*/}}
{{- define "drainer-configmap.data" -}}
drainer-config: |-
    {{- if .Values.binlog.drainer.config }}
{{ .Values.binlog.drainer.config | indent 2 }}
    {{- else -}}
{{ tuple "config/_drainer-config.tpl" . | include "helm-toolkit.utils.template" | indent 2 }}
    {{- end -}}
{{- end -}}

{{- define "drainer-configmap.data-digest" -}}
{{ include "drainer-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{/*
Encapsulate tikv-importer configmap data for consistent digest calculation
*/}}
{{- define "importer-configmap.data" -}}
config-file: |-
    {{- if .Values.importer.config }}
{{ .Values.importer.config | indent 2 }}
    {{- end -}}
{{- end -}}

{{- define "importer-configmap.data-digest" -}}
{{ include "importer-configmap.data" . | sha256sum | trunc 8 }}
{{- end -}}

{{/*
Get a new random password
*/}}
{{- define "tidb-cluster.randomPassword" -}}
{{- randAlpha 1 -}}{{- randAlphaNum 9 -}}
{{- end -}}

{{/*
Get password secret name
*/}}
{{- define "tidb-cluster.tidb.passwordSecretName" }}
{{- if .Values.tidb.passwordSecretName }}
{{- .Values.tidb.passwordSecretName }}
{{- else -}}
{{- if .Values.tidb.auth.enabled -}}
{{ printf "%s-tidb-credentials" (include "cluster.name" .) }}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Get root password or generate random
*/}}
{{- define "tidb-cluster.tidb.rootPassword" }}
{{- $pwd := include "tidb-cluster.tidb.getRootPassword" . }}
{{- include "helm.kv.getOrSet" (dict "context" $ "key" "tidb-cluster.tidb.rootPassword" "value" $pwd) -}}
{{- end }}

{{- define "tidb-cluster.tidb.getRootPassword" }}
{{- if .Values.tidb.auth.rootPassword }}
{{- .Values.tidb.auth.rootPassword }}
{{- else -}}
{{- $secrets := (lookup "v1" "Secret" .Release.Namespace (include "tidb-cluster.tidb.passwordSecretName" .)).data -}}
{{- if hasKey $secrets "root" }}
{{- index $secrets "root" | b64dec -}}
{{- else -}}
{{- include "tidb-cluster.randomPassword" . -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Get password or generate random
*/}}
{{- define "tidb-cluster.tidb.password" }}
{{- $pwd := include "tidb-cluster.tidb.getPassword" . }}
{{- include "helm.kv.getOrSet" (dict "context" $ "key" "tidb-cluster.tidb.password" "value" $pwd) -}}
{{- end }}

{{- define "tidb-cluster.tidb.getPassword" }}
{{- if .Values.tidb.auth.password }}
{{- .Values.tidb.auth.password }}
{{- else -}}
{{- $secrets := (lookup "v1" "Secret" .Release.Namespace (include "tidb-cluster.tidb.passwordSecretName" .)).data -}}
{{- if hasKey $secrets .Values.tidb.auth.username }}
{{- index $secrets .Values.tidb.auth.username | b64dec -}}
{{- else -}}
{{- include "tidb-cluster.randomPassword" . -}}
{{- end -}}
{{- end -}}
{{- end }}
