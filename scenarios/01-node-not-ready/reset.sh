#!/usr/bin/env bash
# Reset Scenario 01 — restarts kubelet on all worker nodes
set -euo pipefail
YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Restarting kubelet on all worker nodes..."
CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1 || echo "")
if [[ -n "$CLUSTER_NAME" ]]; then
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" systemctl start kubelet && echo "  started kubelet on $node"
  done
fi
echo "Reset complete. Run: kubectl get nodes"
