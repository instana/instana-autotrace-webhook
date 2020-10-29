# Instana Autotrace Webhook

This project provides a Kubernetes [admission controller mutating webhook](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/), called Instana Autotrace Webhook, that automatically configures the Instana tracing on Node.js and .NET Core applications (and soon more stuff :-) ) running across the entire Kubernetes cluster.

## Requirements

- Kubernetes 1.16+ OR OpenShift 4.5+
- `kubectl` 1.16+
- Helm 3.2+ (in the setup instructions, we use the new `--create-namespace` flag for maximum comfort)

## Setup

Replace `<download_key>` in the following script with valid Instana download key and run it with administrator priviledges for your cluster:

```bash
helm install --create-namespace --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook \
  --set webhook.imagePullCredentials.password=<download_key>
```

## Verify it works

First of all, ensure the `instana-autotrace-webhook` in the `instana-autotrace-webhook` namespace is running as expected:

```bash
$ kubectl get pods -n instana-autotrace-webhook
NAME                                         READY   STATUS    RESTARTS   AGE
instana-autotrace-webhook-7c5d5bf6df-82w7c   1/1     Running   0          12m
```

Then time to try it out.
Deploy a Node.js pod.
When it comes up, you will see the following when checking the labels of the pod:

```bash
$ kubectl get pod test-nodejs -n test-apps -o=jsonpath='{.metadata.labels.instana-autotrace-applied}'
true
```

Assuming that you _also_ installed the Instana host agent, e.g., using the `instana/agent` helm chart, the Node.js process will soon appear in your Instana dashboard.
For more information, refer to the [Installing the Host Agent on Kubernetes](https://www.instana.com/docs/setup_and_manage/host_agent/on/kubernetes) documentation.

## Updates

The Instana Autotrace Webhook does not currently have an automated way of upgrading the instrumentation it will install.
The instrumentation is delivered over the [`instana/instrumentation` image](https://hub.docker.com/repository/docker/instana/instrumentation).
The `instana-autotrace-webhook` Helm chart will be regularly updated to use the newest `instana/instrumentation` image; so, to update the instrumentation to the latest and greatest version, you can upgrade the deployment with:

```bash
helm upgrade --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook
```

## Gotchas and Known Limitations

- The Instana Autotrace Webhook will take effect on _new_ Kubernetes resources.
  That is, you may need to delete your Pods, ReplicaSets and Deployments and create them anew, for the Instana Autotrace Webhook to do its magic.
- The .NET Core SDK is not automatically installed by the AutoTrace webhook.
- Autoprofile and collecting some runtime metrics will only work on Node.js version 12.
  A future version of the Helm chart will deliver native modules for other supported Node.js versions.
- Environment variables applicable only for Node.js and .NET Core will show up in processes running in other runtimes.
  There is no known side-effect of this, don't get spooked :-)
- Only amd64 Kubernetes nodes are currently supported.

## Configuration

### Role-based Access Control

In order to deploy the Autotrace Webhook into a `ServiceAccount` guarded by a `ClusterRole` and matching `ClusterRoleBinding`, set the `rbac.enabled=true` flag when deploying the Helm chart.

### Container port

In order to be reachable from Kubernetes' API server, the Autotrace Webhook pod _must_ be hosted on the host network, and the deployment is configured to achieve that transparently.
By default, the container will be bound to port `42650`.
If something else on your nodes already uses port `42650`, causing the Autotrace Webhook to go in a crash loop because it finds its port already bound, you can change the port using the `webhook.port` property.

### Opt-in or opt-out

In purely Instana fashion, the Autotrace Webhook will instrument all containers in all pods.
However, you may want to have more control over which pod is instrumented and which not.
By setting the `autotrace.opt-in=true` value when deploying the Helm chart, the Autotrace Webhook will only modify pods that carry the `instana.autotrace: true` label.

Irrespective of the value of the `autotrace.opt-in`, the Autotrace Webhook will _not_ touch pods that carry the `instana.autotrace: false` label

## Changelog

### 0.7.0

- Improvement: Ensure the Autotrace Webhook port binds to the host network; Kubernetes' API Server would not be able to reach the Autotrace Webhook if it runs on top of a overlay networks
- Improvement: Change default port for the Autotrace Webhook port from the `8443` to `42650` to reduce the likelihood of conflicts on the host network
- Improvement: Introduced the `webhook.port` property to override the default value of `42650` for the Autotrace Webhook port
- Improvement: Reduce chattiness of the `debug` mode to debug SSL (because certs are still the hardest thing in 2020)
- Documentation: Document the limitation that the Autotrace Webhook does not currently ship the .NET Core SDK
- Fix: Bind the service correctly if the namespace used is not the default `instana-autotrace-webhook`

### v0.6.0

- Ensure compatibility with GKE `1.16`

### v0.5.0

- Work towards support Helm chart upgrades to deliver new instrumentation, see the [Updates](#updates) section for more information.
