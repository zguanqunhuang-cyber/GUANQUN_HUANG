#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-apply}"
ENV_FILE="${2:-.env}"

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-openim.sh [apply|delete|status] [env-file]

apply   - Create/update namespaces, secrets, configmaps, infra, and OpenIM pods.
delete  - Remove the deployed resources (Secrets, Deployments, Services, etc.).
status  - Show the current state of the namespace.

The script expects an env file (default: .env) that defines at least:
  OPENIM_NAMESPACE, OPENIM_DEPLOY_DIR, BOOTSTRAP_INFRA,
  REDIS_PASSWORD, MONGO_USERNAME, MONGO_PASSWORD,
  MINIO_ACCESS_KEY, MINIO_SECRET_KEY, KAFKA_PASSWORD (optional).
EOF
}

case "${ACTION}" in
  apply|delete|status) ;;
  *) usage; exit 1 ;;
esac

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Env file '${ENV_FILE}' not found. Copy .env.example to ${ENV_FILE} and update the values." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

OPENIM_NAMESPACE="${OPENIM_NAMESPACE:-openim}"
OPENIM_DEPLOY_DIR="${OPENIM_DEPLOY_DIR:-Open-IM-Server/deployments/deploy}"
BOOTSTRAP_INFRA="$(printf '%s' "${BOOTSTRAP_INFRA:-false}" | tr '[:upper:]' '[:lower:]')"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd kubectl

if [[ ! -d "${OPENIM_DEPLOY_DIR}" ]]; then
  echo "OPENIM_DEPLOY_DIR '${OPENIM_DEPLOY_DIR}' does not exist. Clone Open-IM-Server and update the path." >&2
  exit 1
fi

current_context="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "${current_context}" ]]; then
  echo "kubectl has no active context. Configure your cloud kubeconfig before running the script." >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

render_b64_or_empty() {
  local raw="${1:-}"
  if [[ -z "${raw}" ]]; then
    printf '""'
  else
    printf '%s' "${raw}" | LC_ALL=C base64 | tr -d '\n'
  fi
}

ensure_namespace() {
  if kubectl get namespace "${OPENIM_NAMESPACE}" >/dev/null 2>&1; then
    log "Namespace '${OPENIM_NAMESPACE}' already exists."
  else
    log "Creating namespace '${OPENIM_NAMESPACE}'."
    kubectl create namespace "${OPENIM_NAMESPACE}"
  fi
}

delete_namespace() {
  if kubectl get namespace "${OPENIM_NAMESPACE}" >/dev/null 2>&1; then
    log "Deleting namespace '${OPENIM_NAMESPACE}'."
    kubectl delete namespace "${OPENIM_NAMESPACE}" --wait=false
  else
    log "Namespace '${OPENIM_NAMESPACE}' does not exist; skipping delete."
  fi
}

apply_secrets() {
  log "Applying Redis secret."
  kubectl apply -n "${OPENIM_NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openim-redis-secret
type: Opaque
data:
  redis-password: $(render_b64_or_empty "${REDIS_PASSWORD:-}")
EOF

  log "Applying Mongo secret."
  kubectl apply -n "${OPENIM_NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openim-mongo-secret
type: Opaque
data:
  mongo_openim_username: $(render_b64_or_empty "${MONGO_USERNAME:-}")
  mongo_openim_password: $(render_b64_or_empty "${MONGO_PASSWORD:-}")
EOF

  log "Applying MinIO secret."
  kubectl apply -n "${OPENIM_NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openim-minio-secret
type: Opaque
data:
  minio-root-user: $(render_b64_or_empty "${MINIO_ACCESS_KEY:-}")
  minio-root-password: $(render_b64_or_empty "${MINIO_SECRET_KEY:-}")
EOF

  log "Applying Kafka secret."
  kubectl apply -n "${OPENIM_NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openim-kafka-secret
type: Opaque
data:
  kafka-password: $(render_b64_or_empty "${KAFKA_PASSWORD:-}")
EOF
}

delete_secrets() {
  for secret in openim-redis-secret openim-mongo-secret openim-minio-secret openim-kafka-secret; do
    log "Deleting secret ${secret}."
    kubectl delete -n "${OPENIM_NAMESPACE}" secret "${secret}" --ignore-not-found
  done
}

apply_config() {
  local config="${OPENIM_DEPLOY_DIR}/openim-config.yml"
  if [[ ! -f "${config}" ]]; then
    echo "Config map file '${config}' not found. Did the Open-IM-Server repo move?" >&2
    exit 1
  fi
  log "Applying ConfigMap from ${config}."
  kubectl apply -n "${OPENIM_NAMESPACE}" -f "${config}"
}

delete_config() {
  log "Deleting openim-config ConfigMap."
  kubectl delete -n "${OPENIM_NAMESPACE}" configmap openim-config --ignore-not-found
}

apply_cluster_role() {
  local cr="${OPENIM_DEPLOY_DIR}/clusterRole.yml"
  if [[ -f "${cr}" ]]; then
    log "Applying cluster role."
    kubectl apply -f "${cr}"
  fi
}

delete_cluster_role() {
  local cr="${OPENIM_DEPLOY_DIR}/clusterRole.yml"
  if [[ -f "${cr}" ]]; then
    log "Deleting cluster role."
    kubectl delete -f "${cr}" --ignore-not-found
  fi
}

apply_manifest_list() {
  local action="$1"; shift
  local manifests=("$@")
  local op
  case "${action}" in
    apply) op="apply" ;;
    delete) op="delete --ignore-not-found" ;;
    *) echo "Unsupported manifest action ${action}" >&2; exit 1 ;;
  esac

  for manifest in "${manifests[@]}"; do
    local path="${OPENIM_DEPLOY_DIR}/${manifest}"
    if [[ ! -f "${path}" ]]; then
      echo "Manifest ${path} not found." >&2
      exit 1
    fi
    log "${action} manifest ${manifest}"
    # shellcheck disable=SC2086
    kubectl ${op} -n "${OPENIM_NAMESPACE}" -f "${path}"
  done
}

apply_ingress() {
  local path="${OPENIM_DEPLOY_DIR}/ingress.yml"
  if [[ -f "${path}" ]]; then
    log "Applying ingress ${path}"
    kubectl apply -n "${OPENIM_NAMESPACE}" -f "${path}"
  else
    log "Ingress manifest not found at ${path}, skipping."
  fi
}

delete_ingress() {
  local path="${OPENIM_DEPLOY_DIR}/ingress.yml"
  if [[ -f "${path}" ]]; then
    log "Deleting ingress ${path}"
    kubectl delete -n "${OPENIM_NAMESPACE}" -f "${path}" --ignore-not-found
  fi
}

infra_manifests=(
  redis-service.yml
  redis-statefulset.yml
  mongo-service.yml
  mongo-statefulset.yml
  kafka-service.yml
  kafka-statefulset.yml
  minio-service.yml
  minio-statefulset.yml
)

core_manifests=(
  openim-api-service.yml
  openim-api-deployment.yml
  openim-crontask-deployment.yml
  openim-msggateway-service.yml
  openim-msggateway-deployment.yml
  openim-msgtransfer-service.yml
  openim-msgtransfer-deployment.yml
  openim-push-service.yml
  openim-push-deployment.yml
  openim-rpc-user-service.yml
  openim-rpc-user-deployment.yml
  openim-rpc-friend-service.yml
  openim-rpc-friend-deployment.yml
  openim-rpc-group-service.yml
  openim-rpc-group-deployment.yml
  openim-rpc-msg-service.yml
  openim-rpc-msg-deployment.yml
  openim-rpc-third-service.yml
  openim-rpc-third-deployment.yml
  openim-rpc-auth-service.yml
  openim-rpc-auth-deployment.yml
  openim-rpc-conversation-service.yml
  openim-rpc-conversation-deployment.yml
)

status_report() {
  log "kubectl context: ${current_context}"
  kubectl get namespace "${OPENIM_NAMESPACE}" >/dev/null 2>&1 || {
    echo "Namespace ${OPENIM_NAMESPACE} does not exist yet." >&2
    return 0
  }
  kubectl -n "${OPENIM_NAMESPACE}" get pods
  kubectl -n "${OPENIM_NAMESPACE}" get svc
  kubectl -n "${OPENIM_NAMESPACE}" get deployments
  kubectl -n "${OPENIM_NAMESPACE}" get ingress
}

if [[ "${ACTION}" == "status" ]]; then
  status_report
  exit 0
fi

if [[ "${ACTION}" == "apply" ]]; then
  ensure_namespace
  apply_cluster_role
  apply_secrets
  apply_config
  if [[ "${BOOTSTRAP_INFRA}" == "true" ]]; then
    log "Deploying bundled Redis/Mongo/Kafka/MinIO StatefulSets."
    apply_manifest_list apply "${infra_manifests[@]}"
  else
    log "BOOTSTRAP_INFRA=false; assuming external data services already exist."
  fi
  apply_manifest_list apply "${core_manifests[@]}"
  apply_ingress
  status_report
elif [[ "${ACTION}" == "delete" ]]; then
  delete_ingress
  apply_manifest_list delete "${core_manifests[@]}"
  if [[ "${BOOTSTRAP_INFRA}" == "true" ]]; then
    apply_manifest_list delete "${infra_manifests[@]}"
  fi
  delete_config
  delete_secrets
  delete_cluster_role
  delete_namespace
fi
