#!/usr/bin/env bash
set -euo pipefail
YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Removing disk fill..."

_orb_exec() { orb -m k8s "$@" 2>/dev/null; }

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done

elif k3d cluster list 2>/dev/null | grep -q .; then
  for node in $(k3d node list 2>/dev/null | grep agent | awk '{print $1}'); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done

elif command -v orb &>/dev/null && orb -m k8s true &>/dev/null; then
  _orb_exec sudo rm -rf /tmp/disk-pressure-lab && echo "  cleaned OrbStack VM"

else
  kubectl delete pod disk-filler --ignore-not-found
  [[ -d /tmp/disk-pressure-lab ]] && rm -rf /tmp/disk-pressure-lab && echo "  cleaned local path"
fi

echo "Reset complete."
