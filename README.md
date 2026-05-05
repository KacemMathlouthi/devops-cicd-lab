# devops-cicd-lab

End-to-end DevOps pipeline for a tiny FastAPI service:

- **CI**: Jenkins → uv → pytest → SonarCloud → Quality Gate
- **CD**: Docker build → Trivy scan → Docker Hub push
- **IaC**: Terraform creates a kind cluster, namespace, ingress-nginx, and the kube-prometheus-stack
- **Deploy**: Ansible templates Kubernetes Deployment / Service / Ingress / ServiceMonitor / PrometheusRule and applies them via `kubernetes.core.k8s`
- **Verify**: pipeline curls the live app via the Ingress URL
- **Observe**: Prometheus scrapes app + cluster metrics, Grafana dashboard, AlertManager emails alerts via Resend

The whole thing runs on a laptop. No cloud account required.

## Architecture

```
laptop (host)
├── Docker daemon
│   ├── Network: kind
│   │   └── devops-cicd-lab-control-plane   (the kind k8s node)
│   │       ├── ingress-nginx               (Helm via Terraform)
│   │       ├── monitoring                  (kube-prometheus-stack via Terraform)
│   │       │   ├── Prometheus, Grafana, AlertManager, kube-state-metrics, node-exporter
│   │       └── demo                        (Ansible-deployed)
│   │           ├── Deployment devops-cicd-lab (2 FastAPI pods)
│   │           ├── Service, Ingress (app.127-0-0-1.nip.io)
│   │           ├── ServiceMonitor (Prometheus scrape config)
│   │           └── PrometheusRule  (AppDown alert)
│   │
│   └── Network: devops-tp4_default + kind
│       └── jenkins                         (custom image with all CI tooling)
│
└── Browser-accessible URLs
    ├── http://localhost:8090                  Jenkins UI
    ├── http://app.127-0-0-1.nip.io            FastAPI app
    ├── http://grafana.127-0-0-1.nip.io        Grafana
    ├── http://prometheus.127-0-0-1.nip.io     Prometheus
    └── http://alertmanager.127-0-0-1.nip.io   AlertManager
```

Tools split:
- **Terraform** — cluster + cluster-wide infra (ingress controller, monitoring stack).
- **Ansible** — application-layer Kubernetes objects (deployment, service, ingress, dashboard, scrape config, alert rule).
- **Jenkins** — orchestrates everything per build, idempotent.

## Repo layout

```
.
├── app/                       FastAPI app (router + main module)
├── tests/                     pytest suite, coverage feeds SonarCloud
├── pyproject.toml             uv-managed project (FastAPI + uvicorn + prometheus-client)
├── Dockerfile                 multi-stage uv build, non-root, /healthz probe
├── Jenkinsfile                full pipeline, see "Pipeline stages" below
├── sonar-project.properties   SonarCloud project key / org / coverage path
├── docker-compose.ci.yml      Jenkins + MailHog (MailHog is currently unused; Resend is in use)
├── ci/jenkins.Dockerfile      custom Jenkins image with uv, sonar-scanner, kubectl, helm, terraform, trivy, ansible
├── infra/terraform/           kind cluster, namespace, ingress-nginx (Helm), kube-prometheus-stack (Helm)
├── deploy/ansible/            playbook + jinja2 templates for the app + monitoring objects
└── .env.example               template for local secrets (real .env is gitignored)
```

## Prerequisites on the host

- Linux (tested on WSL2)
- Docker (the user must be in the `docker` group)
- Terraform ≥ 1.5
- `kubectl`
- `uv` (https://docs.astral.sh/uv/)
- `ansible-core` (`uv tool install --with kubernetes ansible-core`)
- `ansible-galaxy collection install kubernetes.core community.general`
- A free GitHub repo for this code
- A free SonarCloud account
- A Docker Hub account (with a Personal Access Token)
- A free Resend account (for AlertManager email — optional if you don't want alerts)

## One-time setup

### 1. Clone and configure secrets

```bash
git clone https://github.com/<you>/devops-cicd-lab.git
cd devops-cicd-lab
cp .env.example .env
# Edit .env and fill in SONAR_TOKEN, DOCKERHUB_USERNAME, DOCKERHUB_TOKEN,
# RESEND_API_KEY, RESEND_TO_EMAIL. Ensure DOCKER_GID matches your host
# (find it with: getent group docker | cut -d: -f3)
```

### 2. SonarCloud

1. Sign in at https://sonarcloud.io with GitHub, import the repo as a new project.
2. **Disable Automatic Analysis** (Administration → Analysis Method) so the Jenkins-driven scan runs without conflicts.
3. Generate a token (My Account → Security → Tokens) and put it in `.env` as `SONAR_TOKEN`.
4. Verify the org slug and project key in `sonar-project.properties` match what SonarCloud created.

### 3. Docker Hub

1. https://hub.docker.com → Account settings → Personal access tokens → Generate (Read & Write).
2. Put your username in `.env` as `DOCKERHUB_USERNAME` and the token as `DOCKERHUB_TOKEN`.
3. Edit `Jenkinsfile` and `infra/terraform/...` if your username differs from the default `kacemmathlouthi`.

### 4. Resend (for alert emails)

1. Sign up at https://resend.com (free tier, no credit card).
2. Use the `onboarding@resend.dev` sender; recipient must be the email you signed up with.
3. Generate an API key (Dashboard → API Keys → Create), put it in `.env` as `RESEND_API_KEY`.
4. Put the recipient address in `.env` as `RESEND_TO_EMAIL`.

### 5. Provision the cluster

```bash
cd infra/terraform
terraform init
terraform apply         # creates kind cluster + ingress-nginx + kube-prometheus-stack (~5 min)
```

After apply, your `~/.kube/config` will have a new context `kind-devops-cicd-lab`.

### 6. First app deploy (from host, before Jenkins exists)

```bash
set -a && source ../../.env && set +a
cd ../../deploy/ansible
ansible-playbook site.yml -e image_tag=latest
```

Confirm:
- `curl http://app.127-0-0-1.nip.io/` returns the FastAPI JSON
- `kubectl --context kind-devops-cicd-lab get pods -n demo` shows 2 pods Running

### 7. Bring up Jenkins

```bash
cd ../..
docker compose -f docker-compose.ci.yml up -d --build       # ~5 min the first time
```

Wait until `docker inspect jenkins --format '{{.State.Health.Status}}'` returns `healthy`.

Get the initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 8. Configure Jenkins (one-time UI clicks at http://localhost:8090)

1. Paste the initial admin password.
2. **Install suggested plugins** (Customize Jenkins screen).
3. Create your real admin user.
4. Save the default Jenkins URL.
5. **Manage Jenkins → Plugins → Available** → install **SonarQube Scanner for Jenkins** → restart when prompted.
6. **Manage Jenkins → Credentials → (global) → Add credentials** — add three:
   - Kind: `Secret text`, ID: `sonar-token`, Secret: your SonarCloud token
   - Kind: `Username with password`, ID: `dockerhub-creds`, Username: your Docker Hub username, Password: your Docker Hub token
   - Kind: `Secret file`, ID: `kind-kubeconfig`, File: a kubeconfig restricted to `kind-devops-cicd-lab` and pointing to `https://devops-cicd-lab-control-plane:6443` (see "Generating the Jenkins kubeconfig" below).
7. **Manage Jenkins → System → SonarQube servers** → check **Environment variables**, add a server named exactly `SonarCloud`, URL `https://sonarcloud.io`, Server authentication token = `sonar-token`.
8. **New Item → Pipeline → name `devops-cicd-lab`**:
   - Definition: `Pipeline script from SCM`
   - SCM: Git, Repository URL: this repo's HTTPS URL, Branch: `*/main`
   - Script Path: `Jenkinsfile`

#### Generating the Jenkins kubeconfig

Jenkins is on the kind docker network and must reach the API server by container name (not `127.0.0.1`).

```bash
sed -E 's|server: https://127\.0\.0\.1:[0-9]+|server: https://devops-cicd-lab-control-plane:6443|' \
    ~/.kube/config > /tmp/k.full
KUBECONFIG=/tmp/k.full kubectl config use-context kind-devops-cicd-lab >/dev/null
KUBECONFIG=/tmp/k.full kubectl config view --minify --raw > /tmp/kubeconfig.jenkins
shred -u /tmp/k.full
```

`/tmp/kubeconfig.jenkins` is the file to upload to Jenkins as the `kind-kubeconfig` Secret File credential.

## Pipeline stages

The single `Jenkinsfile` runs (in order):

| # | Stage | Tool | Outcome |
|---|---|---|---|
| 1 | Checkout | git | Workspace populated, short SHA recorded |
| 2 | Install | uv | `uv sync --frozen` |
| 3 | Unit Tests | pytest | `coverage.xml` + JUnit |
| 4 | Static Analysis | sonar-scanner | Results pushed to SonarCloud |
| 5 | Quality Gate | SonarQube Scanner plugin | `waitForQualityGate abortPipeline: true` |
| 6 | Docker Build | docker | Tags `:BUILD_NUMBER` and `:latest` |
| 7 | Image Scanning | trivy | Reports HIGH+CRITICAL, fails only on fixable CRITICAL |
| 8 | Docker Push | docker | Both tags pushed to Docker Hub |
| 9 | Infrastructure | terraform | `init`, `fmt -check`, `validate`, `plan -out`, `apply <plan>` against shared host state |
| 10 | Configure & Deploy | ansible | Renders k8s manifests with `IMAGE_TAG=$BUILD_NUMBER`, applies them |
| 11 | Smoke Test | curl | `curl --connect-to ... http://app.127-0-0-1.nip.io/`, retries up to 30× |

Trigger it from the Jenkins UI with **Build Now**.

## Day-2 operations

```bash
# View running pods
kubectl --context kind-devops-cicd-lab get pods -A

# Re-deploy locally (without going through Jenkins)
set -a && source .env && set +a
ansible-playbook deploy/ansible/site.yml -e image_tag=latest

# Generate traffic to make Grafana panels move
for i in $(seq 1 200); do curl -s http://app.127-0-0-1.nip.io > /dev/null; done

# Trigger an AppDown alert (waits 2 min before firing, restore quickly)
kubectl --context kind-devops-cicd-lab scale deployment devops-cicd-lab -n demo --replicas=0
# … wait, then …
kubectl --context kind-devops-cicd-lab scale deployment devops-cicd-lab -n demo --replicas=2

# Tear everything down
docker compose -f docker-compose.ci.yml down -v
cd infra/terraform && terraform destroy
```

## Monitoring

- **Grafana**: http://grafana.127-0-0-1.nip.io — login `admin` / `admin`. The `devops-cicd-lab` dashboard auto-imports from a ConfigMap (Ansible-applied). Panels: pods up, restarts, available replicas, total req/sec, pod CPU, pod memory, network in/out, request rate by endpoint.
- **Prometheus**: http://prometheus.127-0-0-1.nip.io — Status → Targets shows `serviceMonitor/demo/devops-cicd-lab/0` with 2 endpoints UP.
- **AlertManager**: http://alertmanager.127-0-0-1.nip.io — alerts visible under Active. Only `AppDown` is routed to email; everything else (kube-system noise, etc.) is dropped at the route level to save Resend's free quota.

## Notes / gotchas

- **kind kube-system targets show DOWN in Prometheus** (kube-controller-manager, kube-scheduler, kube-proxy, etcd). Known kind quirk — these bind to `127.0.0.1` inside the kind container and aren't reachable on the pod IP. Cosmetic only; the lab's app metrics scrape fine.
- **Terraform state is shared between host and Jenkins via a bind mount** (`./infra/terraform → /host-tf-state`). The pipeline copies the state file in/out of its workspace so both host and Jenkins runs converge on the same cluster.
- **Jenkins is on both `devops-tp4_default` and `kind` networks** — declared in `docker-compose.ci.yml`. The kind network is `external: true` so it must already exist (created by the kind cluster).
- **Persistence is disabled** for Grafana, Prometheus, AlertManager (emptyDir). Restart the pods and dashboards/data are reset. Acceptable for the lab — the dashboard JSON is reapplied by Ansible, and Prometheus retains 12h of metrics.

## License

This is course work, not a product. Do whatever you like with it.
