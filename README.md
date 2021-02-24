# Instana AutoTrace WebHook

The Instana AutoTrace WebHook is a Kubernetes [admission controller mutating webhook](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/) that automatically configures the Instana tracing on Node.js, .NET Core and Ruby applications running across the entire Kubernetes cluster.

**Note:** The Instana AutoTrace WebHook is currently in Beta.
It is in a very good shape to be used in most production use-cases, and we will declare General Availability in a few weeks.

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

**Important:** When installing on OpenShift, you _must_ set additionally `--set openshift.enabled=true`.

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

The Instana AutoTrace WebHook does not currently have an automated way of upgrading the instrumentation that it will install.
The instrumentation is delivered over the [`instana/instrumentation` image](https://hub.docker.com/repository/docker/instana/instrumentation).
The `instana-autotrace-webhook` Helm chart will be regularly updated to use the newest `instana/instrumentation` image; so, to update the instrumentation to the latest and greatest version, you can upgrade the deployment with:

```bash
helm upgrade --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook \
  --reuse-values
```

You can find out which version of the AutoTrace WebHook has been applied to which of your resources by looking up the `instana-autotrace-version` label.
The `instana-autotrace-version` label will be applied to the Pods, ReplicaSets, StatefulStes, Deployments and DeploymentConfigs.

## Gotchas

- The Instana AutoTrace WebHook will take effect on _new_ Kubernetes resources.
  That is, you may need to delete your Pods, ReplicaSets, StatefulStes, Deployments and DeploymentConfigs and create them anew, for the Instana AutoTrace WebHook to do its magic.
- Only `linux/amd64` Kubernetes nodes are currently supported.

## Configuration

### Role-based Access Control

In order to deploy the AutoTrace WebHook into a `ServiceAccount` guarded by a `ClusterRole` and matching `ClusterRoleBinding`, set the `rbac.enabled=true` flag when deploying the Helm chart.

In addition to the RBAC, if you use Pod Security Policies, add `rbac.psp.enabled=true` to the Helm arguments.

### Container port

In order to be reachable from Kubernetes' API server, the AutoTrace WebHook pod _must_ be hosted on the host network, and the deployment is configured to achieve that transparently.
By default, the container will be bound to port `42650`.
If something else on your nodes already uses port `42650`, causing the AutoTrace WebHook to go in a crash loop because it finds its port already bound, you can change the port using the `webhook.port` property.

### Opt-in or opt-out

In purely Instana fashion, the AutoTrace WebHook will instrument all containers in all pods.
However, you may want to have more control over which resources are instrumented and which not.
By setting the `autotrace.opt_in=true` value when deploying the Helm chart, the AutoTrace WebHook will only modify pods, replica sets, stateful sets, daemon sets and deployments that carry the `instana-autotrace: "true"` label.

Irrespective of the value of the `autotrace.opt_in`, the AutoTrace WebHook will _not_ touch pods that carry the `instana-autotrace: "false"` label.

The `instana-autotrace: "false"` label is respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, and StatefulSets, as well as in nested Pod templates and in standalone Pods.

### Ignoring namespaces

Using the `autotrace.exclude.namespaces` configuration, you can exclude entire namespaces from being auto-instrumented.

Resources that have the `instana-autotrace: "true"` label, will be instrumented regardless of namespace exclusion.

The `instana-autotrace` label is respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, and StatefulSets, as well as in nested Pod templates and in standalone Pods.

### Ignoring resources

Resources that have the `instana-autotrace: "false"` label, will be ignored regardless other settings.

The `instana-autotrace` label is respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, and StatefulSets, as well as in nested Pod templates and in standalone Pods.

## Troubleshooting

If you do not see the Instana AutoTrace WebHook have effect on your _new_ Kubernetes resources, the steps to troubleshoot are the following.

### Ensure the Instana AutoTrace WebHook is receiving requests

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

The logs of your `kube-apiserver` will report on whether the Instana AutoTrace WebHook is being invoked and, if so, what is the outcome.

### (Not so) common issues

#### No network connectivity between kube-apiserver and the instana-autotrace-webhook pods

The most common issue is that the `kube-apiserver` cannot reach the worker nodes running the `instana-autotrace-webhook` pods due to security policies, which prevents the Instana AutoTrace WebHook to work.
In this case, the solution is to change your network settings so that the `kube-apiserver` will be able to reach the `instana-autotrace-webhook` pods.
How to achieve that is entirely dependent on your setup, so we cannot provided guidance on how to solve this case.

#### kube-apiserver and the instana-autotrace-webhook pods cannot negotiate a TLS session

Another issue we have sporadically seen is that cryptography restrictions in terms of which algorithms can be used for TLS prevent `kube-apiserver` from negotiations a TLS session with the `instana-autotrace-webhook` pod.
In this case, please [open a ticket](https://support.instana.com) and tell us which cryptography algorithms your clusters support.
