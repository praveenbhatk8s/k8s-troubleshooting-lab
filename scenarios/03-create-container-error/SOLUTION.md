# Solution — CreateContainerError

## What Happened

The pod was deployed with a `Localhost` seccomp profile pointing to a file that doesn't exist on the node:

```yaml
securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: "profiles/nonexistent-profile.json"
```

The kubelet passes this to containerd, which tries to load the profile from `/var/lib/kubelet/seccomp/profiles/nonexistent-profile.json`. It doesn't exist → containerd returns an error → kubelet reports `CreateContainerError`.

## Diagnosis

```bash
kubectl get pods -n lab-03
# NAME          READY   STATUS                 RESTARTS
# broken-pod    0/1     CreateContainerError   0

kubectl describe pod broken-pod -n lab-03 | grep -A 10 "State:"
# State:       Waiting
#   Reason:    CreateContainerError
#   Message:   failed to create containerd task: ... no such file or directory

kubectl describe pod broken-pod -n lab-03 | tail -20
# Events:
#   Warning  Failed  ...  Error: failed to create containerd task:
#            failed to create shim task:
#            OCI runtime create failed: ...
#            seccomp: opening seccomp profile (/var/lib/kubelet/seccomp/profiles/nonexistent-profile.json) failed: open ... no such file or directory
```

## Fix

Delete the pod and re-apply with `RuntimeDefault` seccomp (or no seccompProfile):

```bash
kubectl delete pod broken-pod -n lab-03

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
        type: RuntimeDefault
  restartPolicy: Never
EOF

kubectl get pods -n lab-03 -w
```

## CreateContainerError vs Other States

| Error | Stage | Cause |
|-------|-------|-------|
| `CreateContainerConfigError` | Pre-runtime (kubelet validation) | Missing Secret/ConfigMap |
| `CreateContainerError` | Runtime (containerd/runc) | Bad seccomp, AppArmor, device, mount |
| `RunContainerError` | Post-create (entrypoint) | Entrypoint binary not found, permission denied |
| `ImagePullBackOff` | Image pull | Wrong image name, registry auth, network |

## Real-World Causes of CreateContainerError

- Missing seccomp profile file on node (`Localhost` type with bad path)
- AppArmor profile not loaded on the node
- `hostPath` volume source doesn't exist on the node (`DirectoryOrCreate` vs `Directory`)
- Device not available (`/dev/sda1` referenced but doesn't exist)
- SELinux label rejection (on RHEL/CentOS nodes)

## Key Commands

```bash
kubectl describe pod <name> -n <ns>                          # Events section
kubectl get pod <name> -n <ns> -o yaml | grep -A5 security  # Check securityContext
crictl inspect <container-id>                                 # Runtime-level inspect (on node)
docker exec <node> journalctl -u containerd -n 30            # containerd logs
```
