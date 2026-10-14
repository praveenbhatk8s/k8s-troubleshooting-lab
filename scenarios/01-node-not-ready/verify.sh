#!/usr/bin/env bash
# Verify Scenario 01 — Node Not Ready
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}  $desc"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC}  $desc"
    ((FAIL++))
  fi
}

echo ""
echo "=== Scenario 01 — Node Not Ready: Verification ==="
echo ""

# All nodes should be Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
check "All nodes are in Ready state" test "$NOT_READY" -eq 0

# Kubelet must be running on all kind/k3d node containers
if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    KUBELET_STATUS=$(docker exec "$node" systemctl is-active kubelet 2>/dev/null || echo "inactive")
    check "kubelet active on $node" test "$KUBELET_STATUS" = "active"
  done
fi

# System pods should be running on all nodes
PENDING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
check "All kube-system pods Running/Completed" test "$PENDING" -eq 0

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED — Well done, Praveen!${NC}"
  echo "The node is healthy. Read SOLUTION.md to review the explanation."
else
  echo -e "${RED}$FAIL check(s) failed.${NC} Keep investigating!"
  echo "Hint: kubectl describe node <node-name> | grep -A5 Conditions"
fi
echo ""
