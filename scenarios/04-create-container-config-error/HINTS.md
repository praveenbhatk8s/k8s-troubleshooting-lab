# Hints — CreateContainerConfigError

## Hint 1

```bash
kubectl get pods -n lab-04
kubectl describe pod broken-pod -n lab-04 | grep -A 20 Events
```

The event message will name the missing resource.

## Hint 2

`CreateContainerConfigError` happens before the container runtime is even involved. The kubelet validates all env/envFrom references at pod start time. If a referenced Secret or ConfigMap doesn't exist (and `optional: false` which is the default), kubelet refuses to create the container.

Check what's missing:
```bash
kubectl get secrets -n lab-04
kubectl get configmaps -n lab-04
```

## Hint 3

There are two missing resources:
- Secret `app-credentials`
- ConfigMap `db-config` (with a key named `host`)

Create them (values don't matter for the pod to start):

```bash
kubectl create secret generic app-credentials \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n lab-04

kubectl create configmap db-config \
  --from-literal=host=postgres.lab-04.svc.cluster.local \
  -n lab-04
```

## Hint 4

Pods in `CreateContainerConfigError` recover automatically once the missing resource is created — you don't need to delete and re-create the pod. Watch it:

```bash
kubectl get pods -n lab-04 -w
```
