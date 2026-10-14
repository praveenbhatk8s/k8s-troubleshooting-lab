#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
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
echo "=== Scenario 07 — OOMKilled: Verification ==="
echo ""

# memory-hog should be Running (limit raised to >= 256Mi)
STATUS_A=$(kubectl get pod memory-hog -n lab-07 --no-headers 2>/dev/null | awk '{print $3}')
check "memory-hog pod is Running" test "$STATUS_A" = "Running"

# memory limit should be >= 128Mi
LIMIT=$(kubectl get pod memory-hog -n lab-07 -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "0")
# Convert Mi to integer for comparison
LIMIT_MI=$(echo "$LIMIT" | sed 's/Mi//' | sed 's/M//')
check "memory-hog limit is >= 128Mi" test "${LIMIT_MI:-0}" -ge 128

# no-limit-hog should have a memory limit set
NO_LIMIT_HAS_LIMIT=$(kubectl get pod no-limit-hog -n lab-07 -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
check "no-limit-hog now has a memory limit" test -n "$NO_LIMIT_HAS_LIMIT"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl describe pod memory-hog -n lab-07 | grep -A5 'Last State'"
  echo "      Look for OOMKilled and exit code 137"
fi
echo ""
