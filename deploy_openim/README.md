# OpenIM Kubernetes Deployment Helper

This workspace follows the official guide at <https://docs.openim.io/guides/gettingStarted/k8s-deployment> and wraps the upstream manifests from `Open-IM-Server/deployments/deploy` with a small helper script so you can push the resources to a cloud Kubernetes cluster quickly and consistently.

## Prerequisites

- An existing Kubernetes cluster (managed service such as ACK/EKS/GKE or your own control plane) and `kubeconfig` credentials on this machine.
- `kubectl` and `helm` installed (already set up via Homebrew in this workspace).
- Access to Redis, MongoDB, Kafka, and MinIO instances, **or** the willingness to run the bundled StatefulSets inside the cluster.

## Repo Layout

- `Open-IM-Server/` – upstream server repo (pulled at deploy time for the manifests).
- `.env.example` – template for deployment-specific inputs (namespace, secrets, etc.).
- `scripts/bootstrap-openim.sh` – orchestration script that applies secrets, config maps, infra (optional), and all OpenIM workloads.

## Usage (Helm)

1. **Update config/secrets via values**
   - Copy `charts/openim/values.yaml` somewhere (or use `--set-file` overrides).
   - Edit the `configFiles` block to reflect your Redis/Mongo/Kafka/MinIO endpoints, ports, and ingress hostnames per the deployment guide.
   - Provide the plaintext credentials under `secrets.*` (Helm handles base64 encoding).

2. **Point kubectl/helm to your cluster**
   ```bash
   kubectl config use-context <your-context>
   helm repo update   # if you rely on remote dependencies
   ```

3. **Install the chart**
   ```bash
   helm upgrade --install openim charts/openim \
     --namespace openim --create-namespace \
     -f charts/openim/values.yaml
   ```
   - Toggle `ingress.enabled`, adjust service types (NodePort vs LoadBalancer) and replica counts through values.
   - The chart generates the ConfigMap, Secrets, Deployments, Services, ClusterRole, and optional ingress automatically.

4. **Check status / rollouts**
   ```bash
   kubectl -n openim get pods,svc,ingress
   helm status openim -n openim
   ```

5. **Upgrade / uninstall**
   ```bash
   helm upgrade openim charts/openim -n openim -f my-values.yaml
   helm uninstall openim -n openim
   ```

## Usage (Legacy Script)

1. **Clone upstream assets (already done here, repeat when updating)**
   ```bash
   git clone https://github.com/OpenIMSDK/Open-IM-Server.git
   ```

2. **Review and edit the config map**
   - Open `Open-IM-Server/deployments/deploy/openim-config.yml`.
   - Update the `discovery.yml` namespace, Redis/Mongo/Kafka/MinIO addresses, `rpc.registerIP`, ingress hostnames, etc., to match your cloud network (per the doc's section “修改配置文件”).

3. **Prepare your env file**
   ```bash
   cp .env.example .env
   ```
   - Set `OPENIM_NAMESPACE`, `OPENIM_DEPLOY_DIR` (if you relocated the repo), and whether you want `BOOTSTRAP_INFRA=true` to deploy the bundled Redis/Mongo/Kafka/MinIO.
   - Fill in the plaintext secrets. The script base64-encodes them.

4. **Point kubectl to your cloud cluster**
   ```bash
   kubectl config use-context <your-context>
   kubectl get nodes
   ```

5. **Deploy everything**
   ```bash
   scripts/bootstrap-openim.sh apply .env
   ```
   The script performs the same sequence described in the guide:
   - Creates/updates the namespace and clusterRole.
   - Creates the ConfigMap from `openim-config.yml`.
   - Creates Secrets for Redis/Mongo/MinIO/Kafka (values from `.env`).
   - Optionally deploys the infra StatefulSets (`BOOTSTRAP_INFRA=true`).
   - Applies all OpenIM Deployments/Services and the `ingress.yml`.

6. **Check status / verification**
   ```bash
   scripts/bootstrap-openim.sh status .env
   kubectl -n <ns> get pods,svc,ingress
   ```
   Test from outside the cluster as suggested in the docs (`telnet msg-gateway.<domain> <port>`, etc.).

7. **Cleanup (if needed)**
   ```bash
   scripts/bootstrap-openim.sh delete .env
   ```

## Notes & Next Steps

- The helper only automates what the doc already prescribes; you still need to provision external services (Redis/Mongo/Kafka/MinIO) or enable `BOOTSTRAP_INFRA`.
- If you use cloud-managed services, update the endpoints/ports in `openim-config.yml` accordingly.
- Before running the script in a production namespace, consider customizing replica counts, resource requests, and ingress TLS.
- The script does not yet wait for rollouts; run `kubectl rollout status deployment/<name> -n <ns>` for each component if you need synchronous confirmation.
