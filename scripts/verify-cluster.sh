#!/bin/bash

# K3s Cluster Verification Script
# Checks MetalLB IP assignment and ArgoCD Application sync status

set -e

echo "=========================================="
echo "K3s Cluster Verification"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
  else
    echo -e "${RED}✗ FAILED${NC}"
  fi
}

echo -e "${YELLOW}1. TRAEFIK SERVICE & METALLB IP ASSIGNMENT${NC}"
echo "================================================"
echo ""
echo "Checking Traefik LoadBalancer service..."
kubectl get svc -n traefik traefik -o wide
echo ""

TRAEFIK_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$TRAEFIK_IP" ]; then
  echo -e "${RED}✗ ERROR: Traefik has no external IP assigned yet${NC}"
  echo "  This could mean MetalLB hasn't assigned an IP yet."
  echo "  Wait a moment and run this script again, or check MetalLB logs."
else
  echo -e "${GREEN}✓ Traefik External IP: $TRAEFIK_IP${NC}"
fi
echo ""

echo -e "${YELLOW}2. METALLB STATUS${NC}"
echo "================================================"
echo ""
echo "MetalLB pods status:"
kubectl get pods -n metallb-system -o wide
echo ""

echo "MetalLB IP Address Pool:"
kubectl get ipaddresspools -n metallb-system -o wide
echo ""

echo "MetalLB L2Advertisement:"
kubectl get l2advertisements -n metallb-system -o wide
echo ""

echo "Checking for allocated IPs:"
kubectl get ipaddresses -n metallb-system -o wide 2>/dev/null || echo "No IP addresses allocated yet"
echo ""

echo -e "${YELLOW}3. METALLB CONTROLLER LOGS (Last 20 lines)${NC}"
echo "================================================"
echo ""
CONTROLLER_POD=$(kubectl get pods -n metallb-system -l app.kubernetes.io/name=metallb,app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$CONTROLLER_POD" ]; then
  echo -e "${RED}✗ ERROR: Could not find MetalLB controller pod${NC}"
else
  echo "MetalLB Controller Pod: $CONTROLLER_POD"
  echo ""
  kubectl logs -n metallb-system "$CONTROLLER_POD" --tail=20
fi
echo ""

echo -e "${YELLOW}4. ARGOCD APPLICATION BOOTSTRAP STATUS${NC}"
echo "================================================"
echo ""
echo "Root Application details:"
kubectl get application -n argocd cluster-apps -o wide
echo ""

echo "Root Application sync status:"
kubectl get application -n argocd cluster-apps -o jsonpath='{.status.sync.status}' && echo ""
kubectl get application -n argocd cluster-apps -o jsonpath='{.status.health.status}' && echo ""
echo ""

echo "Full Application status:"
kubectl describe application -n argocd cluster-apps
echo ""

echo -e "${YELLOW}5. ARGOCD APPLICATION CONTROLLER LOGS (Last 30 lines)${NC}"
echo "================================================"
echo ""
APP_CONTROLLER_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$APP_CONTROLLER_POD" ]; then
  echo -e "${RED}✗ ERROR: Could not find ArgoCD application controller pod${NC}"
else
  echo "ArgoCD Application Controller Pod: $APP_CONTROLLER_POD"
  echo ""
  kubectl logs -n argocd "$APP_CONTROLLER_POD" --tail=30
fi
echo ""

echo -e "${YELLOW}6. ARGOCD REPO SERVER LOGS (Last 30 lines - GitHub sync)${NC}"
echo "================================================"
echo ""
REPO_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$REPO_POD" ]; then
  echo -e "${RED}✗ ERROR: Could not find ArgoCD repo server pod${NC}"
else
  echo "ArgoCD Repo Server Pod: $REPO_POD"
  echo ""
  kubectl logs -n argocd "$REPO_POD" --tail=30
fi
echo ""

echo -e "${YELLOW}7. ARGOCD SECRET STATUS (Repository credentials)${NC}"
echo "================================================"
echo ""
if kubectl get secret -n argocd repo-k3s-gitops &>/dev/null && kubectl get secret -n argocd repo-k3s-gitops-secrets &>/dev/null; then
  echo -e "${GREEN}✓ Public and private repository secrets found${NC}"
  kubectl get secret -n argocd repo-k3s-gitops repo-k3s-gitops-secrets -o name
  echo ""
else
  echo -e "${YELLOW}⚠ WARNING: One or more ArgoCD repository secrets are missing${NC}"
fi
echo ""

echo -e "${YELLOW}8. ALL SERVICES OVERVIEW${NC}"
echo "================================================"
echo ""
kubectl get svc -A | grep -E "traefik|argocd|metallb|EXTERNAL"
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
