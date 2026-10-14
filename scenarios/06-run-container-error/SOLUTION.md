# Solution — RunContainerError

## What Happened

Two pods fail at the **process start** stage (after image pull, after container creation):

| Pod | Cause | Exit Code |
|-----|-------|-----------|
| `bad-command` | Entrypoint binary not found in image | 127 (command not found) |
| `permission-denied` | nginx can't bind port 80 as non-root | 1 (permission denied) |

`RunContainerError` means the OCI runtime (`runc`) successfully created the container but the process inside it exited immediately.

## Diagnosis

```bash
kubectl get pods -n lab-06
# bad-command         0/1   RunContainerError   3
# permission-denied   0/1   RunContainerError   5

kubectl logs bad-command -n lab-06
# exec /usr/local/bin/nonexistent-binary: no such file or directory

kubectl logs permission-denied -n lab-06
# nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)
# nginx: [emerg] still could not bind

kubectl describe pod bad-command -n lab-06 | grep -A 5 "Last State:"
# Exit Code: 127   ← command not found

kubectl describe pod permission-denied -n lab-06 | grep -A 5 "Last State:"
# Exit Code: 1     ← application error
```

## Fix — bad-command

```bash
kubectl delete pod bad-command -n lab-06
kubectl run bad-command --image=nginx:alpine \
  -n lab-06 --restart=Never \
  -l scenario=06,case=a
# No command override → uses image default ENTRYPOINT
```

## Fix — permission-denied

```bash
kubectl delete pod permission-denied -n lab-06
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: permission-denied
  namespace: lab-06
  labels:
    scenario: "06"
    case: "b"
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:alpine   # listens on 8080, designed for non-root
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
  restartPolicy: Never
EOF
```

## Exit Code Cheat Sheet

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success (normal exit) |
| 1 | General application error |
| 2 | Misuse of shell builtins |
| 126 | Permission denied (found but can't execute) |
| 127 | Command not found |
| 128+N | Killed by signal N (e.g. 137 = SIGKILL = OOMKilled) |
| 137 | OOMKilled (128 + 9) |
| 143 | SIGTERM (graceful shutdown, 128 + 15) |

## RunContainerError vs CrashLoopBackOff

| State | Meaning |
|-------|---------|
| `RunContainerError` | Process failed to start (exit immediately, low restart count) |
| `CrashLoopBackOff` | Container started but keeps crashing; kubelet in backoff |

`CrashLoopBackOff` is the state after several `RunContainerError` / short-lived container cycles with exponential backoff applied.

## Key Commands

```bash
kubectl logs <pod> -n <ns>               # stdout/stderr from the container
kubectl logs <pod> -n <ns> --previous    # logs from the PREVIOUS crash
kubectl describe pod <pod> -n <ns>       # Exit Code, Last State
```
