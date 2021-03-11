# Changelog

## 1.196.0

- Update the @instana/collector Node.js package to 1.117.0
- Update the .NET Core dependencies to 1.195.5

## 1.195.10

- Update the @instana/collector Node.js package to 1.116.0
- Update the @instana/collector Node.js package to 1.115.1

## 1.195.9


## 1.195.8

- Update the .NET Core dependencies to 1.195.4

## 1.195.7

- Update the .NET Core dependencies to 1.195.3
- Use Instana SaaS-based versioning scheme for tags and Helm chart version

## 1.195.6

- Use SaaS-based versioning scheme also for tags and Helm chart version

## 1.195.5

- Fix issue with misnamed secret that prevented pulling webhook images
- Create containers-instana-io secret only when the webhook image comes from containers.instana.io
- Change default imagePullPolicy of WebHook and Instrumentation image to 'IfNotPresent'

## 1.195.4

- Update the instana Gem to 1.195.1
- Fix initialization bug due to missing default value for 'autotrace.ruby.enabled'

## 1.195.3

- Add Chart AppVersion as value of new 'instana-autotrace-version' on modified resources

## 1.195.2

- Update the instana Gem to 1.195.0

## 1.195.1

- Update the .NET Core dependencies to 1.195.1

## 1.194.4

- Update the @instana/collector Node.js package to 1.115.0
- Set memory limits for webhook pod

## 1.194.3

- Update the instana Gem to 1.193.6
- Add support for Ruby
- Configure WebHook resource requests to be CPU-burstable

## 1.194.2

- Promote Instana AutoTrace WebHook to BETA

## 1.194.1


## 1.194.0


## 1.193.3

- Update the @instana/collector Node.js package to 1.114.0

## 1.193.2

- Update the .NET Core dependencies to 1.193.4

## 1.193.1

- Update the .NET Core dependencies to 1.193.3

## 1.193.0

- Update the .NET Core dependencies to 1.193.1
- Update the @instana/collector Node.js package to 1.113.0
- Update the @instana/collector Node.js package to 1.112.1
- Improve OpenShift RBAC setup

## 1.192.3

- Update the @instana/collector Node.js package to 1.112.0

## 1.192.2

- Reduce amount of added labels
- Improvements to WebHook logs
- Introduce readiness and liveness probes for the WebHook
- Update the .NET Core dependencies to 1.192.3
- BugFix: Fix webhook upgrade deadlock on small clusters
- BugFix: Fix issue with ignored objects on edit
- Update the @instana/collector Node.js package to 1.111.1

## 1.192.1

- Add memory and cpu limits and requests to instrumentation containers

## 1.192.0

- Update the .NET Core dependencies to 1.192.2

## 1.191.8

- Update the @instana/collector Node.js package to 1.111.0
- Update the .NET Core dependencies to 1.191.20

## 1.191.7

- Update the .NET Core dependencies to 1.191.18

## 1.191.6

- Support OpenShift's DeploymentConfig object

## 1.191.5

- Update the @instana/collector Node.js package to 1.110.5
- Update the .NET Core dependencies to 1.191.11

## 1.191.4

- Update the @instana/collector Node.js package to 1.110.2

## v0.21.0

- Update the @instana/collector Node.js package to 1.110.2

## v0.20.0

There is no version v0.20.0 :-)

## v0.19.0

- Improvement: Allow to specify `securityContext` for the webhook pod and the instrumentation init containers, using the `webhook.pod.securityContext` and `autotrace.instrumentation.securityContext`, respectively.
- Deprecation: The `securityContext.runAsUser` setting has been removed, and you can achieve the same effect via the `webhook.pod.securityContext.runAsUser` setting.

## v0.18.0

- Improvement: Support the `instana-autotrace` label also in metadata of DaemonSets, Deployments, ReplicaSets, and StatefulSets.

## v0.17.0

- Fix: Correct documentation and coding issues with `autotrace.opt_in`

## v0.16.0

- Instrumentation updates

## v0.15.0

- Instrumentation updates

## v0.14.0

- Instrumentation updates

## v0.12.0

- Native addons for Node.js are now bundled for all support Node.js versions!
- Update to the latest tracers

## v0.11.0

- Update to the latest tracers

## v0.10.0

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

## v0.9.0

- Fix: Fix an issue with containers running Node.js v8, where a pod crash could be triggered by the following error:

  ```log
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: secure_getenv: symbol not found
  ```

## v0.8.0

- Fix: Fix an issue with containers running on Alpine or other Muslc-based environment, where a pod crash could be triggered by the following error:

  ```log
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: __snprintf_chk: symbol not found
  Error relocating /opt/instana/instrumentation/libinstana_init/libinstana_init.so: __vfprintf_chk: symbol not found
  ```

## v0.7.0

- Improvement: Ensure the AutoTrace Webhook port binds to the host network; Kubernetes' API Server would not be able to reach the AutoTrace Webhook if it runs on top of a overlay networks
- Improvement: Change default port for the AutoTrace Webhook port from the `8443` to `42650` to reduce the likelihood of conflicts on the host network
- Improvement: Introduced the `webhook.port` property to override the default value of `42650` for the AutoTrace Webhook port
- Improvement: Reduce chattiness of the `debug` mode to debug SSL (because certs are still the hardest thing in 2020)
- Documentation: Document the limitation that the AutoTrace Webhook does not currently ship the .NET Core SDK
- Fix: Bind the service correctly if the namespace used is not the default `instana-autotrace-webhook`

## v0.6.0

- Ensure compatibility with GKE `1.16`

## v0.5.0

- Work towards support Helm chart upgrades to deliver new instrumentation, see the [Updates](#updates) section for more information.
