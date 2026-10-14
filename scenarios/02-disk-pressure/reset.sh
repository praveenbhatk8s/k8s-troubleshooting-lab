#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1 || echo "")
if [[ -n "$CLUSTER_NAME" ]]; then
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    docker exec "$node" rm -rf /disk-pressure-lab && echo "Cleaned $node"
  done
fi
echo "Reset complete."
