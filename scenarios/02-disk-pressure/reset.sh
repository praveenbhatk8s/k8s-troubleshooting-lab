#!/usr/bin/env bash
set -euo pipefail

# Auto-detect OrbStack Docker socket
if [[ -S "${HOME}/.orbstack/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"
fi
YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Removing disk fill..."

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done
elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  for node in $(docker ps --format '{{.Names}}' 2>/dev/null | grep "k3d-${C}-agent"); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "  cleaned $node"
  done
elif command -v orb &>/dev/null; then
  orb sudo rm -rf /tmp/disk-pressure-lab && echo "  cleaned OrbStack VM"
else
  kubectl delete pod disk-filler --ignore-not-found
  [[ -d /tmp/disk-pressure-lab ]] && rm -rf /tmp/disk-pressure-lab && echo "  cleaned local path"
fi

echo "Reset complete."
