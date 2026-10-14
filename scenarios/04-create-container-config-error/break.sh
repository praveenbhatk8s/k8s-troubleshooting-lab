#!/usr/bin/env bash
# Scenario 04 — CreateContainerConfigError
# Simulates: pod references a Secret that doesn't exist
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 04 — CreateContainerConfigError"
echo ""

kubectl create namespace lab-04 --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
  namespace: lab-04
  labels:
    scenario: "04"
spec:
  containers:
  - name: app
    image: nginx:alpine
    envFrom:
    - secretRef:
        name: app-credentials    # This secret does not exist
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: db-config        # This ConfigMap also does not exist
          key: host
  restartPolicy: Never
EOF

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} Pod 'broken-pod' deployed in namespace lab-04"
echo ""
echo "Your tasks:"
echo "  1. Identify the pod's error state"
echo "  2. Find exactly which resource is missing"
echo "  3. Create the missing resources so the pod starts"
echo ""
echo "Useful starting point: kubectl get pods -n lab-04"
