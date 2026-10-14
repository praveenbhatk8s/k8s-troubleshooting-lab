#!/usr/bin/env bash
# Scenario 01 — Node Not Ready
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 01 — Node Not Ready"
echo ""

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop kubelet

elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  WORKER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "k3d-${C}-agent" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent container found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d (${C})  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop k3s-agent

elif command -v orb &>/dev/null; then
  NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  OrbStack  |  ${YELLOW}Target:${NC} $NODE"
  echo "Stopping k3s inside OrbStack VM ..."
  orb sudo systemctl stop k3s 2>/dev/null || orb sudo systemctl stop k3s-agent 2>/dev/null
  echo -e "${YELLOW}NOTE:${NC} API server may also stop on a single-node cluster."

elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (agent)"
  sudo systemctl stop k3s-agent

elif systemctl is-active --quiet k3s 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (server)"
  echo "Stopping in 5s ... Ctrl-C to abort."; sleep 5
  sudo systemctl stop k3s

else
  echo -e "${RED}Could not detect cluster type.${NC}"
  echo "Supported: kind, k3d (detected via node names), OrbStack, bare k3s"
  exit 1
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} kubelet stopped. Node will be NotReady in ~40s."
echo ""
echo "Tasks:"
echo "  1. Find which node is NotReady"
echo "  2. WHY? (kubectl describe node <name>)"
echo "  3. Fix it — return the node to Ready"
echo ""
echo "Starting point: kubectl get nodes -w"
