# Instana AutoTrace Webhook

This project provides a Kubernetes [admission controller mutating webhook](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/), called Instana AutoTrace Webhook, that automatically configures the Instana tracing on Node.js and .NET Core applications (and soon more stuff :-) ) running across the entire Kubernetes cluster.

**Note:** The Instana AutoTrace Webhook is currently in Technical Preview.
It is in a good enough shape to be used in most production use-cases, but not generally available yet due to the limitations listed in the [Limitations to be lifted before GA](#limitations).

## Requirements

- Kubernetes 1.16+ OR OpenShift 4.5+
- `kubectl` 1.16+
- Helm 3.2+ (some automation relies on Helm `lookup` functionality)

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

If, on the other hand, you do _not_ see the `instana-autotrace-applied` labels appear on your containers, consult the [Troubleshooting](#troubleshooting) section.

## Updates

The Instana AutoTrace Webhook does not currently have an automated way of upgrading the instrumentation it will install.
The instrumentation is delivered over the [`instana/instrumentation` image](https://hub.docker.com/repository/docker/instana/instrumentation).
The `instana-autotrace-webhook` Helm chart will be regularly updated to use the newest `instana/instrumentation` image; so, to update the instrumentation to the latest and greatest version, you can upgrade the deployment with:

```bash
helm upgrade --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook
```

## Gotchas

- The Instana AutoTrace Webhook will take effect on _new_ Kubernetes resources.
  That is, you may need to delete your Pods, ReplicaSets and Deployments and create them anew, for the Instana AutoTrace Webhook to do its magic.
- Only amd64 Kubernetes nodes are currently supported.

## Limitations

The following limitations need to be lifted before the Instana AutoTrace Webhook enters Beta:

- Support for PodSecurityPolicies and Security Context for both the WebHook pod and the Instrumentation image.
- Environment variables applicable only for Node.js and .NET Core will show up in processes running in other runtimes.
  There is no known side-effect of this, don't get spooked :-)

From Beta to General Availability, we expect it to be only about ironing bugs, should they come up.

## Configuration

### Role-based Access Control

In order to deploy the AutoTrace Webhook into a `ServiceAccount` guarded by a `ClusterRole` and matching `ClusterRoleBinding`, set the `rbac.enabled=true` flag when deploying the Helm chart.

### Container port

In order to be reachable from Kubernetes' API server, the AutoTrace Webhook pod _must_ be hosted on the host network, and the deployment is configured to achieve that transparently.
By default, the container will be bound to port `42650`.
If something else on your nodes already uses port `42650`, causing the AutoTrace Webhook to go in a crash loop because it finds its port already bound, you can change the port using the `webhook.port` property.

### Opt-in or opt-out

In purely Instana fashion, the AutoTrace Webhook will instrument all containers in all pods.
However, you may want to have more control over which resources are instrumented and which not.
By setting the `autotrace.opt_in=true` value when deploying the Helm chart, the AutoTrace Webhook will only modify pods, replica sets, stateful sets, daemon sets and deployments that carry the `instana-autotrace: "true"` label.

Irrespective of the value of the `autotrace.opt_in`, the AutoTrace Webhook will _not_ touch pods that carry the `instana-autotrace: "false"` label.

The `instana-autotrace: "false"` label can is respected in metadata of DaemonSets, Deployments, ReplicaSets, and StatefulSets, as well as in nested Pod templates and in standalone Pods.

## Troubleshooting

If you do not see the Instana AutoTrace Webhook have effect on your _new_ Kubernetes resources, the steps to troubleshoot are the following.

### Ensure the InstanaAutoTraceWebhook is receiving requests

Check the logs of the `instana-autotrace-webhook` pod.
Using `kubectl`, you can launch the following command:

```sh
kubectl logs -l app.kubernetes.io/name=instana-autotrace-webhook -n instana-autotrace-webhook
```

In a functioning installation, you will see logs like the following:

```logs
14:41:37.590 INFO  |- [AdmissionReview 48556a1a-7d55-497b-aa9c-23634b089cd1] Applied transformation DefaultDeploymentTransformation to the Deployment 'test-netcore-glibc/test-apps'
14:41:37.588 INFO  |- [AdmissionReview 1d5877cf-7153-4a95-9bfb-de0af8351195] Applied transformation DefaultDeploymentTransformation to the Deployment 'test-nodejs-12/test-apps'
```

If you do _not_ see logs like these, then very likely there is a problem with the Kubernetes setup, see the following section.

### Check the Kube ApiServer logs

The logs of your `kube-apiserver` will report on whether the Instana AutoTrace Webhook is being invoked and, if so, what is the outcome.

### (Not so) common issues

#### No network connectivity between kube-apiserver and the instana-autotrace-webhook pods

The most common issue is that the `kube-apiserver` cannot reach the worker nodes running the `instana-autotrace-webhook` pods due to security policies, which prevents the Instana AutoTrace Webhook to work.
In this case, the solution is to change your network settings so that the `kube-apiserver` will be able to reach the `instana-autotrace-webhook` pods.
How to achieve that is entirely dependent on your setup, so we cannot provided guidance on how to solve this case.

#### kube-apiserver and the instana-autotrace-webhook pods cannot negotiate a TLS session

Another issue we have sporadically seen is that cryptography restrictions in terms of which algorithms can be used for TLS prevent `kube-apiserver` from negotiations a TLS session with the `instana-autotrace-webhook` pod.
In this case, please [open a ticket](https://support.instana.com) and tell us which cryptography algorithms your clusters support.

## Changelog

### v0.19.0

- Improvement: Allow to specify `securityContext` for the webhook pod and the instrumentation init containers, using the `webhook.pod.securityContext` and `autotrace.instrumentation.securityContext`, respectively.
- Deprecation: The `securityContext.runAsUser` setting has been removed, and you can achieve the same effect via the `webhook.pod.securityContext.runAsUser` setting.

### v0.18.0

- Improvement: Support the `instana-autotrace` label also in metadata of DaemonSets, Deployments, ReplicaSets, and StatefulSets.

### v0.17.0

- Fix: Correct documentation and coding issues with `autotrace.opt_in`

### v0.16.0

- Instrumentation updates

### v0.15.0

- Instrumentation updates

### v0.14.0

- Instrumentation updates

### v0.12.0

- Native addons for Node.js are now bundled for all support Node.js versions!
- Update to the latest tracers

### v0.11.0

- Update to the latest tracers

### v0.10.0

- Note: The Instana AutoTrace Webhook graduates to Technical Preview status!
- Improvement: Added support in the Helm chart for affinities and tolerations for the Webhook pods, using the `webhook.affinity` (defaulting to `{}`) and `webhook.tolerations` (defaulting to `[]`), respectively.
- Improvement: Support .NET Core applications that use the Instana .NET Core SDK.
- Improvement: Changed default webhook service port from `443` to `42650` to avoid conflicts on EKS, and made it configurable via the `webhook.service.port` setting.
- Improvement: Cleaned up log messages, use consistent format.
- Improvement: Change webhook endpoint from `/validate` to `/mutate` to be more explicit about what it does.
- Improvement: Add support for additional labels and annotations at pod, deployment and service level.
- Refactoring: Renamed the `webhook.replicas` setting to `webhook.deployment.replicas`
- Fix: Correctly ignore Pods based on namespace filtering when they are specified over Deployments, DaemonSets, ReplicaSets and StatefulSets.
- Documentation: Added a [Troubleshooting](#troubleshooting) session.

### v0.9.0

- Fix: Fix an issue with containers running Node.js v8, where a pod crash could be triggered by the following error:

  ```log
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: secure_getenv: symbol not found
  ```

### v0.8.0

- Fix: Fix an issue with containers running on Alpine or other Muslc-based environment, where a pod crash could be triggered by the following error:

  ```log
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: __snprintf_chk: symbol not found
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: __vfprintf_chk: symbol not found
  ```

### v0.7.0

- Improvement: Ensure the AutoTrace Webhook port binds to the host network; Kubernetes' API Server would not be able to reach the AutoTrace Webhook if it runs on top of a overlay networks
- Improvement: Change default port for the AutoTrace Webhook port from the `8443` to `42650` to reduce the likelihood of conflicts on the host network
- Improvement: Introduced the `webhook.port` property to override the default value of `42650` for the AutoTrace Webhook port
- Improvement: Reduce chattiness of the `debug` mode to debug SSL (because certs are still the hardest thing in 2020)
- Documentation: Document the limitation that the AutoTrace Webhook does not currently ship the .NET Core SDK
- Fix: Bind the service correctly if the namespace used is not the default `instana-autotrace-webhook`

### v0.6.0

- Ensure compatibility with GKE `1.16`

### v0.5.0

- Work towards support Helm chart upgrades to deliver new instrumentation, see the [Updates](#updates) section for more information.
