# Instana Autotrace Webhook

This project provides a Kubernetes [admission controller mutating webhook](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/), called Autotrace Webhook, that automatically configures the Instana tracing on Node.js applications running across the entire Kubernetes cluster.

## Requirements

- Kubernetes Cluster 1.17+ OR OpenShift 4.4+ (which is based on Kubernetes 1.17+)
- `kubectl` 1.17+
- Helm 3.2+ (to run tests, we use the `--create-namespace` flag)

## Setup

### Helm 3

Replace `<download_key>` in the following script with valid Instana download key and run it with administrator priviledges for your cluster:

```bash
kubectl get namespace instana-autotrace-webhook > /dev/null 2>&1 || kubectl create namespace instana-autotrace-webhook
./helm/scripts/webhook-create-signed-cert.sh --namespace instana-autotrace-webhook --service instana-autotrace-webhook --secret instana-autotrace-webhook-certs
[ -n "$(kubectl config current-context)" ] || echo 'kubectl config current-context is not set!'
export CA_BUNDLE="$(kubectl config view --raw --flatten -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')"
helm install --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --set webhook.imagePullCredentials.password=<download_key> \
  --set webhook.ssl.caBundle="${CA_BUNDLE}" \
  helm/
```

## Configuration

### Role-based Access Control

In order to deploy the Autotrace Webhook into a `ServiceAccount` guarded by a `ClusterRole` and matching `ClusterRoleBinding`, set the `rbac.enabled=true` flag when deploying the Helm chart.

### Opt-in or opt-out

In purely Instana fashion, the Autotrace Webhook will instrument all containers in all pods.
However, you may want to have more control over which pod is instrumented and which not.
By setting the `autotrace.opt-in=true` property, the Autotrace Webhook will only modify pods that carry the `instana.autotrace: true` label.

Irrespective of the value of `autotrace.opt-in`, the Autotrace Webhook will _not_ touch pods that carry the `instana.autotrace: false` label

### Pinning Instrumentation Versions

The instrumentation is delivered into your containers via an `init-container` that uses, by default, the `latest` version of the `instana/instrumentation` image.
You can however override this behavior by adding the `instana-instrumentation` label to your pods, and then the Autotrace Webhook will use the value of that label as `image` for the init container.
The list of available versions of the `instana/instrumentation` is [available on DockerHub](https://hub.docker.com/v2/repositories/instana/instrumentation/tags).

Additionally, you can override globally the default instrumentation image by setting the `autotrace.instrumentation.image` property when you deploy the Helm chart.
