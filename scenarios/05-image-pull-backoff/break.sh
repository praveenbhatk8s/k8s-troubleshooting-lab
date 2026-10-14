#!/usr/bin/env bash
# Scenario 05 — ImagePullBackOff
# Three sub-cases: wrong tag, private registry no creds, wrong registry
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 05 — ImagePullBackOff (3 sub-cases)"
echo ""

kubectl create namespace lab-05 --dry-run=client -o yaml | kubectl apply -f -

# Case A: Wrong image tag
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wrong-tag
  namespace: lab-05
  labels:
    scenario: "05"
    case: "a"
spec:
  containers:
  - name: app
    image: nginx:this-tag-does-not-exist-99999
  restartPolicy: Never
EOF

# Case B: Wrong registry hostname
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wrong-registry
  namespace: lab-05
  labels:
    scenario: "05"
    case: "b"
spec:
  containers:
  - name: app
    image: nonexistent-registry.internal.corp/myapp:latest
  restartPolicy: Never
EOF

# Case C: Private image, no imagePullSecret
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-pull-secret
  namespace: lab-05
  labels:
    scenario: "05"
    case: "c"
spec:
  containers:
  - name: app
    image: ghcr.io/praveen-bhat-lab/private-app:latest
  restartPolicy: Never
EOF

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} 3 pods deployed in namespace lab-05"
echo ""
echo "Your tasks:"
echo "  - wrong-tag:      fix the image tag"
echo "  - wrong-registry: fix the registry URL"
echo "  - no-pull-secret: add the imagePullSecret"
echo ""
echo "Useful starting point: kubectl get pods -n lab-05"
