#!/usr/bin/env bash
# Scenario 01 — Node Not Ready
# Simulates: kubelet stopped on a worker node
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 01 — Node Not Ready"
echo ""

# ── Detect cluster type ────────────────────────────────────────────────────────
if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found. Does your kind cluster have worker nodes?${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target node:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop kubelet

elif k3d cluster list 2>/dev/null | grep -q .; then
  WORKER=$(k3d node list 2>/dev/null | grep agent | awk '{print $1}' | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d  |  ${YELLOW}Target node:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop k3s-agent

elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
  WORKER="$(hostname)"
  echo -e "${YELLOW}Cluster type:${NC}  k3s (multi-node, agent)  |  ${YELLOW}Target node:${NC} $WORKER"
  echo "Stopping k3s-agent ..."
  sudo systemctl stop k3s-agent

elif systemctl is-active --quiet k3s 2>/dev/null; then
  WORKER="$(hostname)"
  echo -e "${YELLOW}Cluster type:${NC}  k3s (single-node server)"
  echo -e "${RED}WARNING:${NC} Single-node k3s — stopping k3s also stops the API server."
  echo "This scenario works best on a multi-node cluster."
  echo "Stopping k3s in 5s ... Ctrl-C to abort."
  sleep 5
  sudo systemctl stop k3s

else
  echo -e "${RED}Could not detect kind, k3d, or k3s cluster.${NC}"; exit 1
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} kubelet stopped on: ${WORKER}"
echo "Node will be NotReady in ~40 seconds."
echo ""
echo "Tasks:"
echo "  1. Find which node is NotReady"
echo "  2. WHY is it NotReady? (kubectl describe node, events)"
echo "  3. Fix it so the node returns to Ready"
echo ""
echo "Useful starting point: kubectl get nodes -w"
