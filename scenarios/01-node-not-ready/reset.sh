#!/usr/bin/env bash
set -euo pipefail
YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[RESET]${NC} Restarting kubelet..."

_orb_exec() { orb -m k8s "$@" 2>/dev/null; }

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" systemctl start kubelet && echo "  started kubelet on $node"
  done

elif k3d cluster list 2>/dev/null | grep -q .; then
  for node in $(k3d node list 2>/dev/null | grep agent | awk '{print $1}'); do
    docker exec "$node" systemctl start k3s-agent && echo "  started k3s-agent on $node"
  done

elif command -v orb &>/dev/null; then
  if _orb_exec systemctl list-units --all k3s-agent.service | grep -q k3s-agent; then
    _orb_exec sudo systemctl start k3s-agent && echo "  started k3s-agent in OrbStack VM"
  else
    _orb_exec sudo systemctl start k3s && echo "  started k3s in OrbStack VM"
  fi

elif systemctl list-units --all k3s-agent.service 2>/dev/null | grep -q k3s-agent; then
  sudo systemctl start k3s-agent && echo "  started k3s-agent"

elif systemctl list-units --all k3s.service 2>/dev/null | grep -q k3s; then
  sudo systemctl start k3s && echo "  started k3s"

else
  echo "Could not detect cluster type. Start k3s manually."; exit 1
fi

echo "Reset complete. Run: kubectl get nodes"
