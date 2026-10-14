#!/usr/bin/env bash
set -euo pipefail

# Auto-detect OrbStack Docker socket
if [[ -S "${HOME}/.orbstack/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"
fi
YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Restarting kubelet / k3s agent..."

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}
_k3d_agents() { docker ps -a --format '{{.Names}}' 2>/dev/null | grep "k3d-$1-agent"; }

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" systemctl start kubelet && echo "  started kubelet on $node"
  done

elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  # k3d containers have no systemd — restart the container; k3d's entrypoint re-launches k3s
  for node in $(_k3d_agents "$C"); do
    echo "  Restarting container $node ..."
    docker restart "$node"
  done
  echo "  Waiting for k3s agent to come back up ..."
  sleep 8

elif command -v orb &>/dev/null; then
  orb sudo systemctl start k3s 2>/dev/null || orb sudo systemctl start k3s-agent 2>/dev/null
  echo "  started k3s in OrbStack VM"

elif systemctl list-units --all k3s-agent.service 2>/dev/null | grep -q k3s-agent; then
  sudo systemctl start k3s-agent && echo "  started k3s-agent"

elif systemctl list-units --all k3s.service 2>/dev/null | grep -q k3s; then
  sudo systemctl start k3s && echo "  started k3s"

else
  echo "Could not detect cluster type. Start k3s manually."; exit 1
fi

echo ""
echo -e "${GREEN}[RESET COMPLETE]${NC}"
echo "Run: kubectl get nodes -w"
echo "(The node should return to Ready within ~60 seconds)"
