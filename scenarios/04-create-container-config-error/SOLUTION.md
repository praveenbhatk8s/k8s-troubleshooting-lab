# Solution — CreateContainerConfigError

## What Happened

The pod's container spec referenced two non-existent resources:
1. `secretRef: app-credentials` (used in `envFrom`)
2. `configMapKeyRef: db-config` (key `host`, used in `env`)

The kubelet performs config validation before calling the container runtime. When a referenced Secret or ConfigMap is missing, the kubelet sets the container state to `CreateContainerConfigError` and keeps retrying.

This is different from `CreateContainerError` — no container runtime call ever happens here.

## Diagnosis

```bash
kubectl get pods -n lab-04
# broken-pod   0/1   CreateContainerConfigError   0

kubectl describe pod broken-pod -n lab-04 | grep -A 5 "State:"
# State: Waiting
#   Reason: CreateContainerConfigError
#   Message: couldn't find key host in ConfigMap lab-04/db-config

# Or for the Secret:
# Message: secret "app-credentials" not found

kubectl get secrets -n lab-04   # empty
kubectl get configmaps -n lab-04 # only kube-root-ca.crt
```

## Fix

Create both missing resources:

```bash
kubectl create secret generic app-credentials \
  --from-literal=username=admin \
  --from-literal=password=changeme \
  -n lab-04

kubectl create configmap db-config \
  --from-literal=host=postgres.lab-04.svc.cluster.local \
  --from-literal=port=5432 \
  -n lab-04
```

The pod recovers automatically (no delete needed):

```bash
kubectl get pods -n lab-04 -w
# broken-pod   1/1   Running   0   10s
```

## The `optional` Flag

You can make env references tolerant of missing resources:

```yaml
envFrom:
- secretRef:
    name: app-credentials
    optional: true   # pod starts even if secret missing
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: host
      optional: true
```

Use `optional: true` for non-critical config. For credentials, the default (`false`) is safer — you want the pod to fail loudly if secrets are missing rather than start without them.

## Comparison Table

| Error | When | Missing resource type |
|-------|------|-----------------------|
| `CreateContainerConfigError` | kubelet validation | Secret, ConfigMap, ServiceAccount |
| `CreateContainerError` | container runtime | seccomp profile, AppArmor, device |

## Key Commands

```bash
kubectl describe pod <name> -n <ns> | grep -A 10 Events
kubectl get secrets -n <ns>
kubectl get configmaps -n <ns>
kubectl create secret generic <name> --from-literal=key=val -n <ns>
kubectl create configmap <name> --from-literal=key=val -n <ns>
```
