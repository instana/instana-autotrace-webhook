# Instana AutoTrace webhook

The Instana AutoTrace webhook is a Kubernetes [admission controller mutating webhook](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/) that automatically configures the Instana tracing on Node.js, .NET Core, Ruby and Pyhton applications as well as `ingress-nginx` ingress controllers running across the entire Kubernetes cluster. Tracing for IBM MQ and IBM ACE is configurable.

By default, the webhook only mutates pods and configmaps, which makes updates and uninstallation easier. When a new webhook pod runs, higher-level resources can simply be restarted, which would invoke new pods that would be mutated with the new instrumentation image. If you need the previous behavior of mutating higher-level resources directly (deployments, daemonsets, replicasets, statefulsets, and deploymentconfigs), you can enable it using the `autotrace.enableHigherLevelResourceMutation=true` flag.

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

Alternative to providing the `<download_key>`, it's possible to provide the imagePullSecret by modifying the `values.yaml` file, specifying the secret under `webhook.imagePullSecrets` and passing the file to the helm install command with flag `-f values.yaml`. The imagePullSecret name can also be provided through the helm flag `--set webhook.imagePullSecrets[0].name=my-secret`.

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

The Instana AutoTrace webhook does not currently have an automated way of upgrading the instrumentation that it will install.
The instrumentation is delivered over the `instana/instrumentation` image (`icr.io/instana/instrumentation`).
The `instana-autotrace-webhook` Helm chart will be regularly updated to use the newest `instana/instrumentation` image; so, to update the instrumentation to the latest and greatest version, you can upgrade the deployment with:

```bash
helm upgrade --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook
```

You can find out which version of the AutoTrace webhook has been applied to which of your resources by looking up the `instana-autotrace-version` label.
The `instana-autotrace-version` label will be applied to the the mutated resources.

## Gotchas

- The Instana AutoTrace webhook will take effect on _new_ Kubernetes resources.
  That is, you may need to delete your Pods, ReplicaSets, StatefulStes, Deployments and DeploymentConfigs and create them anew, for the Instana AutoTrace webhook to do its magic.
- The `linux/amd64` Kubernetes nodes are currently fully supported and `linux/s390x` have support for Ruby, Python, Node.js, IBM ACE and IBM MQ.
- In your Kubernetes setup, updating the webhook via Helm doesn't automatically pull the latest image, leading to potential mismatches between new code and old images. To address this, uninstalling and reinstalling the webhook can ensure it uses the latest default values and images, but previously deployed workloads may still require redeployment to apply the updated instrumentation.

## Advanced Configuration

### Webhook Failure Policy

The webhook's failure policy determines what happens when the webhook fails to respond to admission requests:

```yaml
autotrace:
  # Valid values: "Ignore" or "Fail"
  failurePolicy: Ignore
```

- `failurePolicy: Ignore` (default): Kubernetes will proceed with the request even if the webhook fails to respond. This is safer for production environments as it ensures workloads can still be scheduled even if the webhook is unavailable.

- `failurePolicy: Fail`: Kubernetes will reject the request if the webhook fails to respond. This is useful for testing environments where you want to ensure all pods are properly instrumented.

You can set this option when installing or upgrading the chart:

```bash
helm install --namespace instana-autotrace-webhook instana-autotrace-webhook \
  --repo https://agents.instana.io/helm instana-autotrace-webhook \
  --set autotrace.failurePolicy=Fail
```

## Configuration

### Enable `ingress-nginx` tracing

To enable the automatic instrumentation of `ingress-nginx` objects in your kubernetes cluster, please set the value of `autotrace.ingress_nginx.enabled` to `true`:

```
--set autotrace.ingress_nginx.enabled=true
```

**Note:** Changes to already existing objects are only done whenever the objects are either modified or recreated.

### Role-based Access Control

In order to deploy the AutoTrace webhook into a `ServiceAccount` guarded by a `ClusterRole` and matching `ClusterRoleBinding`, set the `rbac.enabled=true` flag when deploying the Helm chart.

In addition to the RBAC, if you use Pod Security Policies, add `rbac.psp.enabled=true` to the Helm arguments.

### Container port

In order to be reachable from Kubernetes' API server, the AutoTrace webhook pod _must_ be hosted on the host network, and the deployment is configured to achieve that transparently.
By default, the container will be bound to port `42650`.
If something else on your nodes already uses port `42650`, causing the AutoTrace webhook to go in a crash loop because it finds its port already bound, you can change the port using the `webhook.port` property.

### Opt-in or opt-out

In purely Instana fashion, the AutoTrace webhook will instrument all containers in all pods.
However, you may want to have more control over which resources are instrumented and which not.
By setting the `autotrace.opt_in=true` value when deploying the Helm chart, the AutoTrace webhook will only modify Pods, ReplicaSet, StatefulSets, DaemonSet, Deployments or Namespaces that carry the `instana-autotrace: "true"` label.

Irrespective of the value of the `autotrace.opt_in`, the AutoTrace webhook will _not_ touch pods that carry the `instana-autotrace: "false"` label.

The `instana-autotrace: "false"` label is respected in metadata of Namespaces, as well as in nested Pod templates and in standalone Pods. If the flag `autotrace.enableHigherLevelResourceMutation=true` is set, then label is  respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, StatefulSets as well.

### Ignoring namespaces

Using the `autotrace.exclude.namespaces` configuration, you can exclude entire namespaces from being auto-instrumented.
Helm is... quaint... around list-like data structures when passing values from the command line with `--set`, so you will need to do something like the following:

```sh
helm upgrade instana-autotrace-webhook ... --set autotrace.exclude.namespaces[0]=ignore_this_namespace
```

The `[0]` in the list above is the positional argument in the list of ignored namespaces, which is in this case a list of one element (list indexes start from `0` in Helm).

If you want to ignore multiple namespaces, you will need to do the following:

```sh
helm upgrade instana-autotrace-webhook ... --set autotrace.exclude.namespaces[0]=ignore_this_namespace --set autotrace.exclude.namespaces[1]=ignore_this_other_namespace_too
```

Notice that, even when using `--reuse-values`, you will still need to specify the _whole list of excluded namespaces_ (Helm does not support appending to lists), which is not convenient.
In case of wanting to exclude namespaces, the suggested approach is to use a `values.yaml` file instead.

#### Built-in ignored namespaces

The Helm chart has a built-in list of excluded namespacesm, like `kube-*` and `openshift-*`.
Due to the lack of list-append capability of Helm, they are stored in a separate list called `autotrace.exclude.builtin_namespaces`.
It is strongly advised not to change that list.
We are likely to grow that list over time, and if you modify it, your modifications may be wiped in the next `helm upgrade`.

#### Ignored namespaces and opt-in resources

Resources that have the `instana-autotrace: "true"` label, will be instrumented regardless of namespace exclusion.

The `instana-autotrace` label is respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, StatefulSets, and Namespaces as well as in nested Pod templates and in standalone Pods.

### Ignoring resources

Resources that have the `instana-autotrace: "false"` label, will be ignored regardless other settings.

The `instana-autotrace` label is respected in metadata of Namespaces, as well as in nested Pod templates and in standalone Pods. If the flag `autotrace.enableHigherLevelResourceMutation=true` is set, then label is respected in metadata of DaemonSets, Deployments, DeploymentConfigs, ReplicaSets, StatefulSets as well.

### Minimize required ephemeral storage

The webhook mutates the pod and adds the initContainer which pulls the image that has instrumentation files for all technologies that are supported (Node.js, .NET Core, Ruby, Python and NGINX) and copies all these files to the pod by the default. The files are stored in the emptyDir volume `instana-instrumentation-volume` under volume mount path `/opt/instana/instrumentation/`. As emptyDir volumes are stored on the local filesystem of the node, this is taking up pod's ephemeral storage usage. The total size of the instrumentation files is around 300MB:

- libinstana_init 5M - required for all technologies
- ibmmq 17M
- ruby 151M
- ibmace 9M
- netcore 4M
- nginx 66M
- nodejs 32M
- python 20M

It's possible to limit the ephemeral storage required and specify webhook to only copy files for _some_ techonologies. This can be done globally for the whole cluster by specifying the helm chart flags or modifying the values file (`--set autotrace.instrumentation.manual.<technology>=true`, where technology can be `nodejs`, `netcore`, `python`, `ruby` or `nginx`).

Alternatively, it is possible to configure it per deployment or pod. For this approach, ensure to set the environment variable in the spec `INSTANA_INSTRUMENT_<technology>=true`, where where technology can be `NODEJS`, `NETCORE`, `PYTHON`, `RUBY` or `NGINX`.

It is possible to specify more than one flag and include instrumentation files for two or more technologies. For more details on the environment variables or helm chart flags, please check the [helm values section](#helm-values).

## Troubleshooting

If you do not see the Instana AutoTrace webhook have effect on your _new_ Kubernetes resources, the steps to troubleshoot are the following.

### Ensure the Instana AutoTrace webhook is receiving requests

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

The logs of your `kube-apiserver` will report on whether the Instana AutoTrace webhook is being invoked and, if so, what is the outcome.

### (Not so) common issues

#### No network connectivity between kube-apiserver and the instana-autotrace-webhook pods

The most common issue is that the `kube-apiserver` cannot reach the worker nodes running the `instana-autotrace-webhook` pods due to security policies, which prevents the Instana AutoTrace webhook to work.
In this case, the solution is to change your network settings so that the `kube-apiserver` will be able to reach the `instana-autotrace-webhook` pods.
How to achieve that is entirely dependent on your setup, so we cannot provided guidance on how to solve this case.

#### kube-apiserver and the instana-autotrace-webhook pods cannot negotiate a TLS session

Another issue we have sporadically seen is that cryptography restrictions in terms of which algorithms can be used for TLS prevent `kube-apiserver` from negotiations a TLS session with the `instana-autotrace-webhook` pod.
In this case, please [open a ticket](https://support.instana.com) and tell us which cryptography algorithms your clusters support.

## [Helm Values](#helm-values)

The most important helm values and the environment variables they map to (which
are used in the mutating webhook itself) are the ones related to the
instrumentation image. You can find a table with an explanation and the
respective environment variable below.

|                                      Helm Value                                       |                    Environment variable                    |                                                                                                                                Explanation                                                                                                                                 |
|:-------------------------------------------------------------------------------------:|:----------------------------------------------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| `.Values.global.version` |           NA           |                                                 Flag for setting the version of both the instrumentation and the webhook image. The flag overwrites any version or sha set as part of the .Values.autotrace.instrumentation.image and .Values.webhook.image                                               |
| `.Values.autotrace.enableHigherLevelResourceMutation` |           NA           |                                                 By default the webhook will only mutate pods and configmaps. When set to "true", the webhook will also mutate higher-level resources such as deployments, daemonsets, replicasets, statefulsets, and deploymentconfigs. Default `false`.                                                 |
|                      `.Values.webhook.imagePullSecrets[x].name`                          |          `NA`                               |                                                                                                         Alternative to providing the `<download_key>` as plaintext flag, it's possible to provide the already created imagePullSecret name directly.
| `.Values.autotrace.exclude.builtin_namespaces` `.Values.autotrace.exclude.namespaces` |           `INSTANA_AUTOTRACE_IGNORED_NAMESPACES`           |                                                 List of kubernetes namespaces to be ignored for autotracing. This includes a list of builtin that are always ignored such  as the ones starting with `instana-` or `kube-`                                                 |
|                         `.Values.autotrace.exclude.selector`                          |                                                            | List of kubernetes namespaces that will be ignored at the configuration-level, resources in this namespace will not be sent to the webhook, resources in namespaces specified in the other exclude fields will be sent through the webhook, but will be ignored at runtime |
|                       `.Values.webhook.image`                       |       NA       |                                                                                                                 Name of the custom webhook image                                                                                                                  |
|                       `.Values.autotrace.instrumentation.image`                       |       `INSTANA_INSTRUMENTATION_INIT_CONTAINER_IMAGE`       |                                                                                                                 Name of the instrumentation image                                                                                                                  |
|                  `.Values.autotrace.instrumentation.imagePullPolicy`                  | `INSTANA_INSTRUMENTATION_INIT_CONTAINER_IMAGE_PULL_POLICY` |                                                                                                           Instrumentation image pull policy (Default IfNotPresent)                                                                                                           |
|                  `.Values.autotrace.instrumentation.imagePullSecret`                  | `INSTANA_INSTRUMENTATION_INIT_CONTAINER_IMAGE_PULL_SECRET` |                                                                                                           Instrumentation image pull secret (If `.Values.autotrace.instrumentation.image` comes from a private regitry)                                                                                                           |
|                              `.Values.autotrace.opt_in`                               |                 `INSTANA_AUTOTRACE_OPT_IN`                 |                       When set to "true", only those pods with the label `instana-autotrace=true`, are going to be autotraced. By default is `false`, and in this case all pods will be autotraced except those the label `instana-autotrace=false`                        |
|                          `.Values.autotrace.nodejs.enabled`                           |                 `INSTANA_AUTOTRACE_NODEJS`                 |                                                                                                             Whether to autotrace Node.js pods. Default `true`.                                                                                                              |
|                            `.Values.autotrace.nodejs.application_type`                |               `INSTANA_AUTOTRACE_NODEJS_APPLICATION_TYPE`               |                                                                                                        How the Customers Node.js app loads its modules. The default is `commonjs`.  If you opt for ESM loading and your Node.js version is 18.19.0 or higher, select `module_v2`. For Node.js versions lower than 18.19.0, use `module_v1`.                                                                                                        |
|                            `.Values.autotrace.nodejs.esm`                             |               `INSTANA_AUTOTRACE_NODEJS_ESM`               |                                                                                                        This variable is deprecated and will be removed in future updates. It determines whether the Node.js application is utilizing ESM or not. This setting is relevant only for Node.js versions below 18.19.0, with the default being `false`. We recommend using `INSTANA_AUTOTRACE_NODEJS_APPLICATION_TYPE` instead.                                                                                                        |
|                          `.Values.autotrace.netcore.enabled`                          |                `INSTANA_AUTOTRACE_NETCORE`                 |                                                                                                            Whether to autotrace NET Core pods. Default `true`.                                                                                                             |
|                           `.Values.autotrace.ruby.enabled`                            |                  `INSTANA_AUTOTRACE_RUBY`                  |                                                                                                              Whether to autotrace Ruby pods. Default `true`.                                                                                                               |
|                          `.Values.autotrace.python.enabled`                           |                 `INSTANA_AUTOTRACE_PYTHON`                 |                                                                                                             Whether to autotrace Python pods. Default `true`.                                                                                                              |
|                       `.Values.autotrace.ingress_nginx.enabled`                       |             `INSTANA_AUTOTRACE_INGRESS_NGINX`              |                                                                                                         Whether to autotrace Ingress NGINX pods. Default `false`.                                                                                                          |
|                   `.Values.autotrace.ingress_nginx.status_enabled`                    |          `INSTANA_AUTOTRACE_INGRESS_NGINX_STATUS`          |                                                                                         When autotrace is enabled for Ingress NGINX, also add an status endpoint. Default `false`.                                                                                         |
|                    `.Values.autotrace.ingress_nginx.status_allow`                     |       `INSTANA_AUTOTRACE_INGRESS_NGINX_STATUS_ALLOW`       |                                                                                     IP address or CIDR mask of the agent to restrict the access to the status endpoint. Default `all`.                                                                                     |
|                      `.Values.autotrace.libinstana_init.enabled`                      |          `INSTANA_AUTOTRACE_USE_LIB_INSTANA_INIT`          |                                                                                                          Whether to use libinstana_init library. Default `true`.                                                                                                           |
|                      `.Values.autotrace.initContainer.memoryLimit`                    |          `INSTANA_AUTOTRACE_INIT_MEMORY_LIMIT`             |                                                                                                          Memory limit of the init container. Defaults to `256Mi`.                                                                                                          |
|                      `.Values.autotrace.initContainer.cpuLimit`                       |          `INSTANA_AUTOTRACE_INIT_CPU_LIMIT`                |                                                                                                         CPU limit of the init container. Defaults to `250m`.                                                                                                               |
|                      `.Values.awseksfargate.enabled`                                  |          `INSTANA_ENVIRONMENT_AWSEKSFARGATE`                 |                                                        Makes the webhook set the `INSTANA_TRACER_ENVIRONMENT` to an EKS Fargate specific value, which enables the EKS Fargate support in the in-process tracer.                                                            |
|                      `.Values.awseksfargate.instanaEndpointURL`                       |          `INSTANA_ENDPOINT_URL`                            |                                                                                                         Specifys the endpoint URL of the serverless agent for the in-process the tracer.                                                                                   |
|                      `.Values.awseksfargate.instanaAgentKey`                          |          `INSTANA_AGENT_KEY`                               |                                                                                                         Specifys the agent key for the in-process tracer, which is used for authentication on the endpoint URL.                                                            |
|                      `.Values.autotrace.instrumentation.manual.nodejs`                          |          `INSTANA_INSTRUMENT_NODEJS`                               |                                                                                                         Flag to explicitely copy files for NodeJS applications. The files for other technologies will be omitted unless manually set with similar flags for other technologies. Helm chart flag sets the configuration globally for the cluster.                                                            |
|                      `.Values.autotrace.instrumentation.manual.netcore`                          |          `INSTANA_INSTRUMENT_NETCORE`                               |                                                                                                         Flag to explicitely copy files for .NET core applications. The files for other technologies will be omitted unless manually set with similar flags for other technologies. Helm chart flag sets the configuration globally for the cluster.                                                            |
|                      `.Values.autotrace.instrumentation.manual.nginx`                          |          `INSTANA_INSTRUMENT_NGINX`                               |                                                                                                         Flag to explicitely copy files for nginx. The files for other technologies will be omitted unless manually set with similar flags for other technologies. Helm chart flag sets the configuration globally for the cluster.                                                            |
|                      `.Values.autotrace.instrumentation.manual.ruby`                          |          `INSTANA_INSTRUMENT_RUBY`                               |                                                                                                         Flag to explicitely copy files for Ruby applications. The files for other technologies will be omitted unless manually set with similar flags for other technologies. Helm chart flag sets the configuration globally for the cluster.                                                            |
|                      `.Values.autotrace.instrumentation.manual.python`                          |          `INSTANA_INSTRUMENT_PYTHON`                               |                                                                                                         Flag to explicitely copy files for Python applications. The files for other technologies will be omitted unless manually set with similar flags for other technologies. Helm chart flag sets the configuration globally for the cluster.
|                      `.Values.autotrace.instrumentation.imagePullCredentials.registry`                          |          NA                               |                                                                                                         The initContainer image can be pulled from private registry by customizing the deployment. This flag can be used to specify the registry for creating the pull secret.
|                      `.Values.autotrace.instrumentation.imagePullCredentials.username`                          |          NA                               |                                                                                                         The initContainer image can be pulled from private registry by customizing the deployment. This flag can be used to specify the username for creating the pull secret.
|                      `.Values.autotrace.instrumentation.imagePullCredentials.password`                          |          NA                               |                                                                                                         The initContainer image can be pulled from private registry by customizing the deployment. This flag can be used to specify the password for creating the pull secret.
|                      `.Values.webhook.priorityClass.name`                          |          NA                               |                                                                                                         Sets the priorityClassName in the webhook deployment. When specified, enables pod priority and preemption as described in the [Kubernetes documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/).
