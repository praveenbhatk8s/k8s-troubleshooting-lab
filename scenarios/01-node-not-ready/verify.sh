#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}  $desc"; ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC}  $desc"; ((FAIL++))
  fi
}

_orb_exec() { orb -m k8s "$@" 2>/dev/null; }

echo ""
echo "=== Scenario 01 — Node Not Ready: Verification ==="
echo ""

NOT_READY=$(kubectl get nodes --no-headers | grep -vc " Ready" || true)
check "All nodes are in Ready state" test "$NOT_READY" -eq 0

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    STATUS=$(docker exec "$node" systemctl is-active kubelet 2>/dev/null || echo "inactive")
    check "kubelet active on $node" test "$STATUS" = "active"
  done

elif k3d cluster list 2>/dev/null | grep -q .; then
  for node in $(k3d node list 2>/dev/null | grep agent | awk '{print $1}'); do
    STATUS=$(docker exec "$node" systemctl is-active k3s-agent 2>/dev/null || echo "inactive")
    check "k3s-agent active on $node" test "$STATUS" = "active"
  done

elif command -v orb &>/dev/null; then
  if _orb_exec systemctl list-units --all k3s-agent.service | grep -q k3s-agent; then
    STATUS=$(_orb_exec systemctl is-active k3s-agent || echo "inactive")
    check "k3s-agent active in OrbStack VM" test "$STATUS" = "active"
  else
    STATUS=$(_orb_exec systemctl is-active k3s || echo "inactive")
    check "k3s active in OrbStack VM" test "$STATUS" = "active"
  fi

elif systemctl list-units --all k3s-agent.service 2>/dev/null | grep -q k3s-agent; then
  STATUS=$(systemctl is-active k3s-agent || echo "inactive")
  check "k3s-agent active" test "$STATUS" = "active"

elif systemctl list-units --all k3s.service 2>/dev/null | grep -q k3s; then
  STATUS=$(systemctl is-active k3s || echo "inactive")
  check "k3s active" test "$STATUS" = "active"
fi

PENDING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -vc "Running\|Completed" || true)
check "All kube-system pods Running/Completed" test "$PENDING" -eq 0

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}  Read SOLUTION.md for the full explanation."
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl describe node <name> | grep -A5 Conditions"
fi
echo ""
