#!/usr/bin/env bash
# Scenario 03 — CreateContainerError
# Simulates: pod references a hostPath that doesn't exist, or a securityContext
# that the container runtime rejects (invalid seccomp profile path)
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 03 — CreateContainerError"
echo ""

kubectl create namespace lab-03 --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
  namespace: lab-03
  labels:
    scenario: "03"
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: "profiles/nonexistent-profile.json"
  restartPolicy: Never
EOF

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} Pod 'broken-pod' deployed in namespace lab-03"
echo ""
echo "Your tasks:"
echo "  1. Identify the pod's state and the exact error"
echo "  2. Understand why CreateContainerError is thrown"
echo "  3. Fix the pod so it reaches Running state"
echo ""
echo "Useful starting point: kubectl get pods -n lab-03"
