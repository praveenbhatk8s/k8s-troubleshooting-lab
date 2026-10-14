#!/usr/bin/env bash
# Scenario 01 — Node Not Ready
# Simulates: kubelet stopped on a worker node
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 01 — Node Not Ready"
echo ""

# Detect cluster type
if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_TYPE="kind"
  CLUSTER_NAME=$(kind get clusters | head -1)
  # Find a worker node container
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found. Does your kind cluster have worker nodes?${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Target node container:${NC} $WORKER"
  echo ""
  echo "Stopping kubelet on $WORKER ..."
  docker exec "$WORKER" systemctl stop kubelet
  echo ""
  echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} kubelet has been stopped on node: $WORKER"
  echo ""
  echo "The node will transition to NotReady in ~40 seconds."
  echo ""
  echo "Your tasks:"
  echo "  1. Find which node is NotReady"
  echo "  2. Understand WHY it is NotReady"
  echo "  3. Fix it so the node returns to Ready"
  echo ""
  echo "Useful starting point: kubectl get nodes"

elif k3d cluster list 2>/dev/null | grep -q .; then
  CLUSTER_TYPE="k3d"
  WORKER=$(k3d node list 2>/dev/null | grep agent | awk '{print $1}' | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Target node container:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop k3s-agent
  echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} k3s-agent stopped on $WORKER"

else
  echo -e "${RED}Could not detect kind or k3d cluster. Adjust WORKER variable for your setup.${NC}"
  exit 1
fi
