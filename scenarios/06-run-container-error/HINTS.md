# Hints — RunContainerError

## Hint 1

```bash
kubectl get pods -n lab-06
kubectl describe pod bad-command -n lab-06 | grep -A 10 Events
kubectl logs bad-command -n lab-06
```

`RunContainerError` means the image was pulled successfully, the container was created, but the process failed to start (exit before becoming "Running").

## Pod: bad-command

**Hint 2:** The command `/usr/local/bin/nonexistent-binary` doesn't exist inside `nginx:alpine`.

```bash
# What commands does nginx:alpine actually have?
kubectl run debug --image=nginx:alpine --restart=Never -it --rm -- ls /usr/local/bin/
```

Fix: delete the pod and re-create with the correct entrypoint (or remove the `command` override to use the image's default).

```bash
kubectl delete pod bad-command -n lab-06
kubectl run bad-command --image=nginx:alpine -n lab-06 --restart=Never -l scenario=06,case=a
```

---

## Pod: permission-denied

**Hint 2:** `nginx` by default tries to bind port 80. Only root (uid 0) can bind ports below 1024. The pod runs as UID 1000.

Check the logs:
```bash
kubectl logs permission-denied -n lab-06
# nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)
```

**Hint 3:** Use `nginx:unprivileged` which is configured to listen on port 8080, or override the nginx config to use a high port.

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
    image: nginxinc/nginx-unprivileged:alpine
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
  restartPolicy: Never
EOF
```
