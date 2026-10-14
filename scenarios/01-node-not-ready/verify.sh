#!/usr/bin/env bash
set -euo pipefail

# Auto-detect OrbStack Docker socket
if [[ -S "${HOME}/.orbstack/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"
fi
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

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}
_k3d_agents() { docker ps --format '{{.Names}}' 2>/dev/null | grep "k3d-$1-agent"; }

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
elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  for node in $(_k3d_agents "$C"); do
    STATUS=$(docker exec "$node" systemctl is-active k3s-agent 2>/dev/null || echo "inactive")
    check "k3s-agent active on $node" test "$STATUS" = "active"
  done
elif command -v orb &>/dev/null; then
  STATUS=$(orb systemctl is-active k3s 2>/dev/null || orb systemctl is-active k3s-agent 2>/dev/null || echo "inactive")
  check "k3s active in OrbStack VM" test "$STATUS" = "active"
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
