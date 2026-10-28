# Project Context: K3s GitOps Foundation

## Overview
This project uses **Ansible** to bootstrap a K3s cluster. Once the foundation is ready, **ArgoCD** takes over to manage the state via GitOps.

This is a **two-repository project** managed together in a VS Code workspace:
- **k3s-gitops** (public): Ansible playbooks, Helm charts, ArgoCD applications (safe to share)
- **k3s-gitops-secrets** (private): Environment-specific values, secrets, credentials (locally-managed)

## Repository Architecture

### Public Repository (`k3s-gitops`)
```
k3s-gitops/
├── ansible/                 # Playbooks, roles, Jinja2 templates
├── bootstrap/               # Root ArgoCD Application manifest
├── apps/                    # ArgoCD Application definitions
├── charts/                  # Custom Helm charts (generic, reusable)
│   ├── cert-manager/
│   ├── code-server/
│   ├── pihole/
│   ├── ingresses/
│   ├── registry/
│   └── ...
└── .github/copilot-instructions.md
```

### Private Repository (`k3s-gitops-secrets`)
```
k3s-gitops-secrets/
└── home-lab/               # Environment-specific values
    ├── cert-manager.yaml   # Real domains, emails, API tokens
    ├── pihole.yaml         # Real IPs, passwords
    ├── ingresses.yaml      # Real external service endpoints
    ├── code-server.yaml
    └── ...
```

### Workspace Setup
Both repos are opened together in `k3s-home-lab.code-workspace`. This allows:
- Cross-repo navigation in a single editor
- Easy reference between public charts and private values
- Separate git histories and remotes
- Copilot context across both repos

## Infrastructure Logic
- **Provisioning:** Ansible handles OS updates, K3s installation, and Helm binary setup.
- **Networking:**
  - **MetalLB:** Provides L2 LoadBalancer IPs (Range defined in inventory).
  - **Traefik v3:** Acts as the Ingress Controller (Static IP assigned via annotations).
- **GitOps Handover:** Ansible applies a "Bootstrap" Application. This app points ArgoCD to both repos:
  - Public repo: Charts and application definitions
  - Private repo: Environment-specific values via `helm.valuesFiles`

## Standards

### Templating
- Use Jinja2 (`.j2`) files for K8s manifests. No heredocs in playbooks.
- Helm charts in `charts/` are generic; environment values go in `k3s-gitops-secrets/home-lab/`.

### Secrets Management
- **NEVER** commit secrets to the public repo.
- **NEVER** hardcode values in `apps/*.yaml` manifests.
- **DO** store all sensitive data (domains, IPs, API tokens, passwords) in the private repo (`k3s-gitops-secrets/home-lab/`).
- Ansible references private values via GitHub token during setup.
- ArgoCD pulls from both repos using registered credentials.

### File Organization
- **Public (`k3s-gitops`):** Generic, sharable, production-grade documentation
- **Private (`k3s-gitops-secrets`):** Your personal configuration, never pushed to public
- **Workspace:** Local development environment connecting both

### Traffic
- Support for both `web` (80) and `websecure` (443).
- Traefik handles TLS termination.
- Cert-Manager provisions Let's Encrypt certificates via Cloudflare DNS solver.

## Key Components
- Namespace `metallb-system`: LoadBalancing.
- Namespace `traefik`: Ingress.
- Namespace `argocd`: Management/GitOps.