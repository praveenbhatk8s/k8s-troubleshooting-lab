# Hints — OOMKilled

## Hint 1

```bash
kubectl get pods -n lab-07 -w
# You'll see: CrashLoopBackOff or OOMKilled in the STATUS column

kubectl describe pod memory-hog -n lab-07 | grep -A 10 "Last State:"
```

Look for:
```
Last State: Terminated
  Reason: OOMKilled
  Exit Code: 137
```

Exit code 137 = 128 + 9 (SIGKILL). The kernel's OOM killer sent SIGKILL to the container process.

## Hint 2 — memory-hog

The container is trying to allocate 128Mi but the limit is 32Mi.

Fix: raise the memory limit to something that accommodates the workload:

```bash
kubectl delete pod memory-hog -n lab-07
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
  namespace: lab-07
  labels:
    scenario: "07"
    case: "a"
spec:
  containers:
  - name: hog
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "128M", "--vm-hang", "1"]
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "256Mi"
  restartPolicy: OnFailure
EOF
```

## Hint 3 — no-limit-hog

No memory limit means the container can consume node memory up to the node's physical limit, potentially starving other pods.

Fix: add a memory limit. First profile the actual usage:

```bash
kubectl top pod no-limit-hog -n lab-07
```

Then add an appropriate limit and re-create the pod:

```yaml
resources:
  requests:
    memory: "64Mi"
  limits:
    memory: "128Mi"
```
