# K3s GitOps Foundation

A secure, fork-friendly Kubernetes GitOps setup using **Ansible** for bootstrapping and **ArgoCD** for GitOps management.

## 📋 Overview

This repository contains:
- **Ansible playbooks** to bootstrap a K3s cluster with all dependencies
- **Helm charts** for deploying cluster services (reusable across environments)
- **ArgoCD Applications** managed via Helm (apps are optional and configurable)
- **Repository architecture** separating public code from private secrets

## 🏗️ Architecture

```
k3s-gitops (Public - Safe to Share)    k3s-gitops-secrets (Private - Never Public)
├── ansible/                           ├── ansible/
│   ├── site.yml                       │   └── inventory.ini (GitHub creds, IPs, domains)
│   └── templates/                     ├── cluster-apps/
├── apps/ (Helm chart)                 │   └── app.yaml (Application manifest + all Helm values)
│   ├── Chart.yaml                     ├── environments/
│   ├── values.yaml                    │   └── home-lab/
│   └── templates/                     │       ├── cert-manager.yaml
├── charts/                            │       ├── pihole.yaml
│   ├── cert-manager/                  │       └── ...
│   ├── pihole/                        └── ...
│   └── ...
```

**Key Principle:**
- Public repo contains only **generic, reusable Helm templates** (zero secrets)
- Private repo contains **all configuration and secrets** (inventory, app definitions, domains, IPs, API tokens)
- **Bootstrap Application never appears in public code** — lives only in private repo
- Ansible applies the private Application directly after ArgoCD setup

## 🚀 Quick Start

### Install

Run the installation playbook with the private inventory:

```bash
ansible-playbook \
  -i ../git-ops/ansible/inventory.ini \
  ansible/site.yml \
  --ask-pass \
  --ask-become-pass
```

For a minimal Debian VM without `sudo`, add `--become-method=su` on the
first run. The playbook detects whether `sudo` is installed and only uses
`su` when it needs to install it.

### Uninstall

To destroy the test cluster, including K3s, workloads, persistent cluster data,
and Helm, run the separate uninstall playbook with explicit confirmation:

```bash
ansible-playbook \
  -i ../git-ops/ansible/inventory.ini \
  ansible/uninstall.yml \
  --ask-pass \
  --ask-become-pass \
  -e confirm_uninstall=true
```

The uninstall playbook leaves SSH and sudo installed so the VM remains
accessible. To keep Helm installed, add `-e remove_helm=false`. This operation
is destructive and should only be used against the intended test VM.

### Configure kubectl locally

The install playbook does not modify the Ansible control machine. After the
cluster is ready, configure local `kubectl` with the separate playbook:

```bash
ansible-playbook \
  -i ../git-ops/ansible/inventory.ini \
  ansible/configure-kubectl.yml \
  --ask-pass \
  --ask-become-pass
```

This writes `~/.kube/k3s-gitops.yaml` and verifies access. It does not install
`kubectl` automatically. For an automated Linux control machine where
`kubectl` is absent, opt in explicitly:

```bash
ansible-playbook \
  -i ../git-ops/ansible/inventory.ini \
  ansible/configure-kubectl.yml \
  --ask-pass \
  --ask-become-pass \
  -e install_kubectl=true
```

Use `-e kubeconfig_path=/path/to/config` to write a different kubeconfig.

### 1. Prerequisites
- Two repositories cloned side-by-side
- Ansible installed on your machine
- SSH access to your cluster nodes
- A supported K3s version; the bootstrap currently pins K3s
  `v1.35.5+k3s1`, which is within the Rancher 2.15 support range.

### 2. Configure Your Deployment
All configuration lives in the **private repo**:

```bash
# Set infrastructure variables
vim k3s-gitops-secrets/ansible/inventory.ini

# Configure all apps and their deployment (with Helm values)
vim k3s-gitops-secrets/cluster-apps/app.yaml

# Individual app configuration files
vim k3s-gitops-secrets/environments/home-lab/cert-manager.yaml
vim k3s-gitops-secrets/environments/home-lab/pihole.yaml
# ... etc
```

Key variables in `inventory.ini`:
- Cluster node IPs
- Domain names, static IPs (MetalLB, Traefik)
- GitHub credentials for ArgoCD repo access

### 3. Run Bootstrap
```bash
cd k3s-gitops
ansible-playbook -i ../k3s-gitops-secrets/ansible/inventory.ini ansible/site.yml
```

The playbook will:
1. ✅ Install K3s on all nodes
2. ✅ Configure MetalLB for LoadBalancer IPs
3. ✅ Deploy Traefik v3 Ingress Controller
4. ✅ Install ArgoCD
5. ✅ Register both repos with stored credentials
6. ✅ Apply `k3s-gitops-secrets/cluster-apps/app.yaml` (all app definitions + Helm values)
7. ✅ ArgoCD deploys all applications

## 🔧 Configuration

### Single Source of Truth: Private Repo

Everything is configured in **one place** — your private `cluster-apps/app.yaml`:

```yaml
# k3s-gitops-secrets/cluster-apps/app.yaml
spec:
  source:
    repoURL: https://github.com/your-username/k3s-gitops.git
    path: apps                          # Public Helm chart (generic templates)
    helm:
    values: |
      cert-manager:
        enabled: true
        chart_revision: main          # Pin version for rollbacks
        values:
          installCRDs: true
          # Private environment values are embedded here.

      pihole:
        enabled: false
        chart_revision: HEAD
        values: {}

      # ... all other apps
```

The public chart does not read private files or repository references. The
private root Application is the source of truth and injects each app's values
inline.

### Making Apps Optional

Toggle any app on/off in `cluster-apps/app.yaml`:

```yaml
keycloak:
  enabled: false         # Won't deploy
  chart_revision: main
  values: {}
```

### Version Pinning for Rollbacks

Set specific chart versions in your private config:

```yaml
traefik:
  enabled: true
  chart_revision: "35.2.0"  # Pin to exact version for rollback control
  values:
    # Private Traefik values go here.
```

### Available Applications

- **cert-manager** - Certificate management (Let's Encrypt)
- **traefik** - Ingress controller with TLS
- **pihole** - DNS & ad-blocking
- **keycloak** - Identity & access management
- **rancher** - Kubernetes management
- **vault** - Secrets management
- **code-server** - VS Code in browser
- **registry** - Docker container registry
- **test-app** - Sample app with image updater
- **ingresses** - Proxies for external services

## 🔐 Security

- **Private data never in public repo** - Secrets stay in `k3s-gitops-secrets`
- **GitHub token-based access** - Repos registered with credentials in ArgoCD
- **Environment-specific values** - Easy multi-environment support
- **Helm templating** - Reusable charts across deployments

## 🍴 Forking

To fork this setup for your own cluster:

1. Fork `k3s-gitops` (public template)
2. Create your own private `k3s-gitops-secrets` repo
3. Adjust `k3s-gitops-secrets/environments/home-lab/` values
4. Update `ansible/inventory.ini` with your infrastructure
5. Run Ansible bootstrap

No hardcoded URLs or secrets to hunt down—everything is templated!

## 🛠️ Detailed Setup

Clone both repositories in the same parent directory:

```bash
mkdir k3s-home-lab
cd k3s-home-lab
git clone https://github.com/your-username/k3s-gitops.git
git clone git@github.com:your-username/k3s-gitops-secrets.git
```

The private repository contains the inventory, environment values, domains,
IP addresses, and credentials. Never commit those files to this repository.

Edit the private inventory:

```bash
vim k3s-gitops-secrets/ansible/inventory.ini
```

It must define the cluster nodes, MetalLB range, Traefik IP, domain,
GitHub username and token, and both repository URLs. Use
[ansible/inventory.ini.example](ansible/inventory.ini.example) as a reference.

Run the bootstrap from the public repository:

```bash
cd k3s-gitops
ansible-playbook \
  -i ../k3s-gitops-secrets/ansible/inventory.ini \
  ansible/site.yml
```

For a first bootstrap on a host without `sudo`:

```bash
ansible-playbook \
  -i ../k3s-gitops-secrets/ansible/inventory.ini \
  ansible/site.yml \
  --ask-pass \
  --ask-become-pass \
  --become-method=su
```

## 🔗 ArgoCD Repository Integration

The bootstrap installs ArgoCD, waits for it to become ready, registers both
repositories using credentials from the private inventory, and applies the
private repository's bootstrap Application.

The resulting ArgoCD repository Secrets contain:

```yaml
type: git
url: https://github.com/your-username/k3s-gitops.git
username: your-username
password: your-github-token
```

The private repository uses the same structure with
`k3s-gitops-secrets.git`. Credentials are stored in Kubernetes Secrets and
must never be written into public manifests.

To verify repository registration:

```bash
kubectl get secrets -n argocd | grep repo-
kubectl get secret repo-k3s-gitops -n argocd \
  -o jsonpath='{.data.url}' | base64 -d
```

Use a least-privilege GitHub token, prefer read-only access where possible,
and rotate credentials regularly.

## ✅ Verification and Troubleshooting

Run the verification script:

```bash
chmod +x scripts/verify-cluster.sh
./scripts/verify-cluster.sh
```

Check MetalLB and Traefik:

```bash
kubectl get svc -n traefik traefik
kubectl get ipaddresspools -n metallb-system
kubectl logs -n metallb-system \
  -l app.kubernetes.io/component=controller --tail=50
```

The Traefik service should have an external IP. If it remains pending, check
that the IP pool exists, has available addresses, and is reachable on the
local network.

Check the ArgoCD bootstrap Application:

```bash
kubectl get application -n argocd cluster-apps
kubectl describe application -n argocd cluster-apps
kubectl get pods -n argocd
```

For synchronization failures, inspect the repository server logs:

```bash
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-repo-server
kubectl get application -n argocd cluster-apps -w
```

For node and workload diagnostics:

```bash
kubectl get pods -A -w
kubectl get svc -A | grep LoadBalancer
kubectl top nodes
kubectl top pods -A
```

For local DNS testing, map the assigned Traefik IP to your own configured
hostnames in `/etc/hosts`, rather than committing those hostnames here:

```text
192.0.2.50  argo.example.com
192.0.2.50  your-app.example.com
```
