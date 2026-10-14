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
echo "=== Scenario 05 — ImagePullBackOff: Verification ==="
echo ""

# Case A: wrong-tag pod should be Running (with corrected tag)
STATUS_A=$(kubectl get pod wrong-tag -n lab-05 --no-headers 2>/dev/null | awk '{print $3}')
check "wrong-tag pod is Running" test "$STATUS_A" = "Running"

# Case B: wrong-registry pod should be Running
STATUS_B=$(kubectl get pod wrong-registry -n lab-05 --no-headers 2>/dev/null | awk '{print $3}')
check "wrong-registry pod is Running" test "$STATUS_B" = "Running"

# Case C: no-pull-secret — either Running OR an imagePullSecret now exists in the ns
PULL_SECRET=$(kubectl get secrets -n lab-05 --field-selector type=kubernetes.io/dockerconfigjson --no-headers 2>/dev/null | wc -l)
STATUS_C=$(kubectl get pod no-pull-secret -n lab-05 --no-headers 2>/dev/null | awk '{print $3}')
check "imagePullSecret created in lab-05" test "$PULL_SECRET" -gt 0
check "no-pull-secret pod is Running or using correct image" bash -c "test '$STATUS_C' = 'Running' || kubectl get pod no-pull-secret -n lab-05 -o yaml | grep -q 'imagePullSecrets'"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl describe pod <name> -n lab-05 | grep -A10 Events"
fi
echo ""
