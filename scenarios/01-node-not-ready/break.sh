#!/usr/bin/env bash
# Scenario 01 — Node Not Ready
# Simulates: kubelet stopped on a worker node
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 01 — Node Not Ready"
echo ""

# ── Detect cluster type ────────────────────────────────────────────────────────

_orb_exec() { orb -m k8s "$@" 2>/dev/null; }

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop kubelet

elif k3d cluster list 2>/dev/null | grep -q .; then
  WORKER=$(k3d node list 2>/dev/null | grep agent | awk '{print $1}' | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop k3s-agent

elif command -v orb &>/dev/null && orb -m k8s systemctl is-active k3s &>/dev/null; then
  # OrbStack k3s VM
  NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  OrbStack k3s  |  ${YELLOW}Target node:${NC} $NODE"
  echo ""
  echo "Stopping k3s inside OrbStack VM ..."
  _orb_exec sudo systemctl stop k3s
  echo ""
  echo -e "${YELLOW}NOTE:${NC} On a single-node OrbStack cluster the API server also stops."
  echo "The node will show NotReady when you restart k3s and the API comes back."

elif command -v orb &>/dev/null && orb -m k8s systemctl is-active k3s-agent &>/dev/null; then
  NODE=$(kubectl get nodes --no-headers | grep -v "control-plane\|master" | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  OrbStack k3s (agent)  |  ${YELLOW}Target node:${NC} $NODE"
  _orb_exec sudo systemctl stop k3s-agent

elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (agent)"
  sudo systemctl stop k3s-agent

elif systemctl is-active --quiet k3s 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (server)"
  echo -e "${RED}WARNING:${NC} Stopping k3s on a single-node cluster also kills the API server."
  echo "Stopping in 5s ... Ctrl-C to abort."; sleep 5
  sudo systemctl stop k3s

else
  echo -e "${RED}Could not detect cluster type.${NC}"
  echo "Supported: kind, k3d, OrbStack k3s, bare k3s"
  exit 1
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} kubelet stopped."
echo "Node will transition to NotReady in ~40 seconds."
echo ""
echo "Tasks:"
echo "  1. Find which node is NotReady"
echo "  2. WHY? (kubectl describe node <name>, check events)"
echo "  3. Fix it — return the node to Ready"
echo ""
echo "Starting point: kubectl get nodes -w"
