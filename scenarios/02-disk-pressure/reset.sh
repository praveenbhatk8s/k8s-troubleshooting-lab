#!/usr/bin/env bash
set -euo pipefail
YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Removing disk fill file..."

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done

elif k3d cluster list 2>/dev/null | grep -q .; then
  for node in $(k3d node list 2>/dev/null | grep agent | awk '{print $1}'); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done

else
  # k3s: delete the filler pod and the hostPath directory
  kubectl delete pod disk-filler --ignore-not-found
  # The hostPath dir is on the node itself — remove it if running locally
  if [[ -d /tmp/disk-pressure-lab ]]; then
    rm -rf /tmp/disk-pressure-lab && echo "  removed /tmp/disk-pressure-lab"
  else
    echo "  /tmp/disk-pressure-lab not found locally — delete it on the node manually"
    echo "  (ssh to the node and run: sudo rm -rf /tmp/disk-pressure-lab)"
  fi
fi

echo "Reset complete."
