# Solution — ImagePullBackOff

## What Happened

Three pods were created with different image pull failures:

| Pod | Root Cause | Event Message |
|-----|-----------|---------------|
| `wrong-tag` | Tag doesn't exist on registry | `manifest unknown` |
| `wrong-registry` | Registry hostname not resolvable | `no such host` / `dial tcp: lookup ...` |
| `no-pull-secret` | Private registry, no auth | `401 Unauthorized` / `pull access denied` |

## The BackOff Mechanism

`ImagePullBackOff` is not the first state — it progresses:

```
ErrImagePull (first attempt)
  → ErrImagePull (retry)
    → ImagePullBackOff (backoff starts: 10s, 20s, 40s... up to 5min)
      → ErrImagePull (retry after backoff)
        → ImagePullBackOff (longer backoff)
```

The kubelet uses exponential backoff to avoid hammering registries.

## Diagnosis

```bash
# For each pod:
kubectl describe pod wrong-tag -n lab-05 | grep -A 10 Events
# Failed to pull image "nginx:this-tag-does-not-exist-99999":
#   manifest for nginx:this-tag-does-not-exist-99999 not found

kubectl describe pod wrong-registry -n lab-05 | grep -A 10 Events
# Failed to pull image "nonexistent-registry.internal.corp/myapp:latest":
#   dial tcp: lookup nonexistent-registry.internal.corp: no such host

kubectl describe pod no-pull-secret -n lab-05 | grep -A 10 Events
# Failed to pull image "ghcr.io/praveen-bhat-lab/private-app:latest":
#   pull access denied, repository does not exist or requires authorization
```

## Fix — Case A (wrong tag)

```bash
kubectl delete pod wrong-tag -n lab-05
kubectl run wrong-tag --image=nginx:alpine \
  -n lab-05 --restart=Never \
  -l scenario=05,case=a
```

## Fix — Case B (wrong registry)

```bash
kubectl delete pod wrong-registry -n lab-05
kubectl run wrong-registry --image=nginx:alpine \
  -n lab-05 --restart=Never \
  -l scenario=05,case=b
```

## Fix — Case C (missing imagePullSecret)

```bash
# Create the secret
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USER> \
  --docker-password=<PAT_TOKEN> \
  -n lab-05

# Re-create pod with the secret
kubectl delete pod no-pull-secret -n lab-05
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
  imagePullSecrets:
  - name: ghcr-creds
  containers:
  - name: app
    image: ghcr.io/praveen-bhat-lab/private-app:latest
  restartPolicy: Never
EOF
```

Or for this lab: switch to `nginx:alpine` (public) and just demonstrate the concept.

## Pro Tips

```bash
# Check what images are already cached on a node (saves pull time)
docker exec cks-worker crictl images

# Force re-pull (set imagePullPolicy: Always)
# Or delete the pod and re-create

# Debug registry auth at the node level
docker exec cks-worker crictl pull nginx:alpine   # test a pull manually

# Service account default pull secret
kubectl get serviceaccount default -n lab-05 -o yaml
# If the SA has imagePullSecrets, all pods in that namespace inherit them
kubectl patch serviceaccount default -n lab-05 \
  -p '{"imagePullSecrets": [{"name": "ghcr-creds"}]}'
```
