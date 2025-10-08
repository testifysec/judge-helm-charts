# Configuring JUDGE Helm Deployments

## Customizing with Helm Charts

[JUDGE](https://testifysec.com/products) offers flexibility in customizing deployments through Helm charts. You can tailor your deployment according to your specific requirements by overriding default values using Helm.

### Using Helm cli args

You can customize the JUDGE umbrella `values.yaml` file when installing our Helm charts from our registry. Helm allows you to override default values specified in the `values.yaml` file of the chart during installation. Here's how you can do it:

```bash
# JAR (JUDGE Artifact Registry)
helm install judge us-east4-docker.pkg.dev/judge-395516/judge-image-registry/judge-chart --set key1=value1,key2=value2

# aws marketplace ecr
helm install judge . \
    -f values.yaml \
    --set global.registry="709825985650.dkr.ecr.us-east-1.amazonaws.com" \
    --set global.repository="testifysec" \
    --set kratos.kratos.config.selfservice.methods.oidc.config.providers[0].client_id="${GITLAB_OIDC_CLIENT_ID}" \
    --set kratos.kratos.config.selfservice.methods.oidc.config.providers[0].client_secret="${GITLAB_OIDC_CLIENT_SECRET}" \
    --wait
```

In this command:

- `judge` is the name you're giving to the release.
- `us-east4-docker.pkg.dev/judge-395516/judge-image-registry/judge-chart` is the location of the chart in the registry.
- `--set` allows you to override specific values defined in the `values.yaml` file. You can specify multiple key-value pairs separated by commas.

#### Using a Separate YAML File

Alternatively, you can also use a separate YAML file to specify the custom values:

```bash
helm install judge us-east4-docker.pkg.dev/judge-395516/judge-image-registry/judge-chart -f values.yaml
```

In this case, `values.yaml` contains the custom values you want to override from the default `values.yaml` file of the chart. This can be very useful when you need to reconfigure many parts of JUDGE.

### Configuration Knobs

Below is a table of all the configuration knobs available in JUDGE that you can override to customize your deployment:

| Parameter                                    | Description                                                 | Default                                                               |
| -------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------- |
| `global.registry` | The domain of a judge oci image registry | `us-east4-docker.pkg.dev` |
| `global.repository` | The path of the oci image registry | `judge-395516/judge-image-registry` |
| `web.replicaCount` | Number of replicas | 1 |
| `web.image.registry` | The domain of a judge oci image registry | `us-east4-docker.pkg.dev` |
| `web.image.repository` | judge-web image repository | `judge-395516/judge-image-registry` |
| `web.image.tag` | tag of the image | `[release or digest]` |
| `web.image.pullPolicy` | Pull policy of the image | `IfNotPresent` ||
| `web.nameOverride` | Override name of app | `""` |
| `web.fullnameOverride` | Override full name of app | `""` |
| `web.serviceAccount.create` | Specifies whether a service account should be created | `true` |
| `web.serviceAccount.automount` | Automatically mount a ServiceAccount's API credentials? | `true` |
| `web.serviceAccount.annotations` | Annotations to add to the service account | `{}` |
| `web.serviceAccount.name` | The name of the service account to use | `""` |
| `web.podAnnotations` | Pod annotations | `{}` |
| `web.podLabels` | Pod labels | `{}` |
| `web.podSecurityContext` | Pod security context | `{}` |
| `web.securityContext` | Security context | `{}` |
| `web.service.type` | The type of service to create | `ClusterIP` |
| `web.service.port` | Port of the service | `8077` |
| `web.ingress.enabled` | Enable or disable ingress | `true` |
| `web.ingress.className` | Ingress class name | `nginx` |
| `web.ingress.annotations` | Ingress annotations | `{cert-manager.io/cluster-issuer: "tls-ca-issuer", kubernetes.io/ssl-redirect: "true", nginx.ingress.kubernetes.io/rewrite-target: "/"}` |
| `web.redirectIngress.enabled` | Enable or disable redirect ingress | `true` |
| `web.redirectIngress.className` | Redirect ingress class name | `nginx` |
| `web.redirectIngress.annotations` | redirectIngress annotations | `{cert-manager.io/cluster-issuer: "tls-ca-issuer", kubernetes.io/ssl-redirect: "true", nginx.ingress.kubernetes.io/use-regex: "true", nginx.ingress.kubernetes.io/rewrite-target: "/$2"}` |
| `web.resources` | Pod resource requests & limits | `{}` |
| `web.autoscaling.enabled` | Enables Kubernetes autoscaling | `false` |
| `web.autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `web.autoscaling.maxReplicas` | Maximum number of replicas | `100` |
| `web.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage | `80` |
| `web.volumes` | Additional volumes on the output Deployment definition | `[]` |
| `web.volumeMounts` | Additional volumeMounts on the output Deployment definition | `[]` |
| `web.nodeSelector` | Node labels for pod assignment | `{}` |
| `web.tolerations` | Tolerations for pod assignment | `[]` |
| `web.affinity` | Map of node/pod affinities | `{}` |
| `judge-api.replicaCount` | Number of replicas | 1 |
| `judge-api.image.registry` | The domain of a judge oci image registry | `us-east4-docker.pkg.dev` |
| `judge-api.image.repository` | JUDGE-API image repository | `judge-395516/judge-image-registry` |
| `judge-api.image.pullPolicy` | Pull policy of the image | `IfNotPresent` |
| `judge-api.image.tag` | JUDGE-API image tag | `"[release or digest]"` |
| `judge-api.image.pullSecrets` | Image pull secrets | `- name: gcr-secret` |
| `judge-api.nameOverride` | Override name of app | `""` |
| `judge-api.fullnameOverride` | Override full name of app | `""` |
| `judge-api.serviceAccount.create` | Specifies whether a service account should be created | `false` |
| `judge-api.serviceAccount.annotations` | Annotations to add to the service account | `{}` |
| `judge-api.serviceAccount.name` | The name of the service account to use | `""` |
| `judge-api.podAnnotations` | Pod annotations | `{}` |
| `judge-api.podSecurityContext` | Pod security context | `{}` |
| `judge-api.securityContext` | Security context | `{}` |
| `judge-api.deployment.env` | Environment variables for the deployment | `KRATOS_PUBLIC_URL`=`"kratos-public.default.svc.cluster.local"`, `KRATOS_ADMIN_URL`=`"kratos-admin.default.svc.cluster.local"` |
| `judge-api.service.type` | The type of service to create | `ClusterIP` |
| `judge-api.service.port` | Port of the service | `8080` |
| `judge-api.ingress.enabled` | Enable or disable ingress | `true` |
| `judge-api.ingress.className` | Ingress class name | `"nginx"` |
| `judge-api.ingress.annotations` | Ingress annotations | `{}` |
| `judge-api.resources` | Pod resource requests & limits | `{}` |
| `judge-api.autoscaling.enabled` | Enables autoscaling for Kubernetes | `false` |
| `judge-api.autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `judge-api.autoscaling.maxReplicas` | Maximum number of replicas | `10` |
| `judge-api.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization for autoscaling | `80` |
| `judge-api.nodeSelector` | Node labels for pod assignment | `{}` |
| `judge-api.tolerations` | Tolerations for pod assignment | `[]` |
| `judge-api.affinity` | Map of node/pod affinities | `{}` |
| `archivista.replicaCount` | Number of replicas for archivista | 1 |
| `archivista.image.registry` | The domain of a judge oci image registry | `us-east4-docker.pkg.dev` |
| `archivista.image.repository` | Archivista image repository | `judge-395516/judge-image-registry` |
| `archivista.image.tag` | Archivista image tag | `[release or digest]` |
| `archivista.image.pullPolicy` | Pull policy for the image | `IfNotPresent` |
| `archivista.nameOverride` | Override name of archivista app | `""` |
| `archivista.fullnameOverride` | Override full name of archivista app | `""` |
| `archivista.deployment.env.ARCHIVISTA_ENABLE_SPIFFE`                                       | SPIFFE enablement | "False" |
| `archivista.deployment.env.ARCHIVISTA_LISTEN_ON`                                           | Archivista service listener address | tcp://0.0.0.0:8082 |
| `archivista.deployment.env.ARCHIVISTA_STORAGE_BACKEND`                     | Specifies the storage backend used by Archivista | BLOB |
| `archivista.deployment.env.ARCHIVISTA_BLOB_STORE_USE_TLS`                 | Indicates if TLS is used for blob store access | "False" |
| `archivista.deployment.env.ARCHIVISTA_BLOB_STORE_ACCESS_KEY_ID`       | Access key ID for blob store | "minio-user" |
| `archivista.deployment.env.ARCHIVISTA_BLOB_STORE_SECRET_ACCESS_KEY_ID` | Secret key ID for blob store access | "minio-password" |
| `archivista.deployment.env.ARCHIVISTA_BLOB_STORE_BUCKET_NAME`            | Bucket name in blob store | "archivista" |
| `archivista.deployment.env.ARCHIVISTA_BLOB_STORE_ENDPOINT`                 | Blob store endpoint | `judge-minio.judge.svc.cluster.local:9000` |
| `archivista.deployment.env.ARCHIVISTA_ENABLE_GRAPHQL`                         | GraphQL enablement | "true" |
| `archivista.deployment.env.ARCHIVISTA_GRAPHQL_WEB_CLIENT_ENABLE`        | GraphQL WebClient enablement | "true" |
| `archivista.deployment.env.ARCHIVISTA_CORS_ALLOW_ORIGINS`                    | Allowed CORS origins | "*" |
| `archivista.deployment.env.MYSQLPASS`                                                        | MySQL password | "root" |
| `archivista.deployment.env.ARCHIVISTA_SQL_STORE_CONNECTION_STRING`        | SQL store connection string | `root:root@tcp(judge-mysql.judge.svc.cluster.local:3306)/archivista` |
| `archivista.serviceAccount.create` | Specifies whether a service account should be created | `false` |
| `archivista.serviceAccount.annotations` | Annotations to add to the service account | `{}` |
| `archivista.serviceAccount.name` | The name of the service account to use | `""` |
| `archivista.podAnnotations` | Pod annotations for archivista | `{}` |
| `archivista.podSecurityContext` | Pod security context for archivista | `{}` |
| `archivista.securityContext` | Security context for archivista | `{}` |
| `archivista.deployment.env` | Environment variables for the deployment | [Specified list of environment variables](#note) |
| `archivista.service.type` | The type of service for archivista | `ClusterIP` |
| `archivista.service.port` | Port of the service for archivista | `8082` |
| `archivista.ingress.enabled` | Enable or disable ingress for archivista | `true` |
| `archivista.ingress.className` | Ingress class name for archivista | `""` |
| `archivista.ingress.annotations` | Ingress annotations for archivista | `{}` |
| `archivista.resources` | Pod resource requests & limits for archivista | `{}` |
| `archivista.autoscaling.enabled` | Enables Kubernetes autoscaling for archivista | `false` |
| `archivista.autoscaling.minReplicas` | Minimum number of replicas for archivista | `1` |
| `archivista.autoscaling.maxReplicas` | Maximum number of replicas for archivista | `10` |
| `archivista.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization for autoscaling | `80` |
| `archivista.nodeSelector` | Node labels for pod assignment in archivista | `{}` |
| `archivista.tolerations` | Tolerations for pod assignment in archivista | `[]` |
| `archivista.affinity` | Map of node/pod affinities in archivista | `{}` |
| `dex.namespace.create`                       | Specifies whether to create a namespace for Dex     | `false`       |
| `dex.namespace.name`                         | Name of the Dex namespace                          | `tsa-system`  |
| `dex.replicaCount`                           | Number of Dex server replicas                      | `1`           |
| `dex.image.repository`                       | Repository for Dex server image                    | `ghcr.io/dexidp/dex` |
| `dex.image.pullPolicy`                       | Pull policy for Dex server image                   | `IfNotPresent` |
| `dex.image.tag`                              | Tag of the Dex image                               | `""`          |
| `dex.imagePullSecrets`                       | Secrets to pull the Dex image                      | `[]`          |
| `dex.nameOverride`                           | Name override for Dex                              | `""`          |
| `dex.fullnameOverride`                       | Full name override for Dex                         | `""`          |
| `dex.hostAliases`                            | Host aliases for Dex pods                          | `[]`          |
| `dex.https.enabled`                          | Enable HTTPS endpoint for Dex                      | `false`       |
| `dex.grpc.enabled`                           | Enable gRPC endpoint for Dex                       | `false`       |
| `dex.configSecret.create`                    | Enable creating a secret from values passed to `config` | `true`   |
| `dex.configSecret.name`                      | Name of the secret to mount as configuration       | `""`          |
| `dex.config`                                 | Application configuration for Dex                  | `{}`          |
| `dex.volumes`                                | Additional volumes for Dex pods                    | `[]`          |
| `dex.volumeMounts`                           | Additional volume mounts for Dex pods              | `[]`          |
| `dex.envFrom`                                | Additional environment variables from secrets or config maps | `[]` |
| `dex.env`                                    | Additional environment variables for Dex containers | `{}`          |
| `dex.envVars`                                | Additional environment variables with support for all possible configurations | `[]` |
| `dex.serviceAccount.create`                  | Enable service account creation for Dex            | `true`        |
| `dex.serviceAccount.annotations`             | Annotations to be added to the service account     | `{}`          |
| `dex.serviceAccount.name`                    | Name of the service account to use                 | `""`          |
| `dex.rbac.create`                            | Enable RBAC resources creation for Dex             | `true`        |
| `dex.rbac.createClusterScoped`               | Enable creation of cluster-scoped RBAC resources for Dex | `true` |
| `dex.deploymentAnnotations`                  | Annotations to be added to deployment              | `{}`          |
| `dex.deploymentLabels`                       | Labels to be added to deployment                   | `{}`          |
| `dex.podAnnotations`                         | Annotations to be added to pods                    | `{}`          |
| `dex.podLabels`                              | Labels to be added to pods                         | `{}`          |
| `dex.podDisruptionBudget.enabled`            | Enable pod disruption budget for Dex               | `false`       |
| `dex.podDisruptionBudget.minAvailable`       | Minimum number of available pods for pod disruption budget | `{}` |
| `dex.podDisruptionBudget.maxUnavailable`     | Maximum number of unavailable pods for pod disruption budget | `{}` |
| `dex.priorityClassName`                      | Pod priority class name for Dex                    | `""`          |
| `dex.podSecurityContext`                     | Pod security context for Dex                       | `{}`          |
| `dex.revisionHistoryLimit`                   | Number of deployment revisions to be kept for Dex  | `10`          |
| `dex.securityContext`                        | Container security context for Dex containers      | `{}`          |
| `dex.service.annotations`                    | Annotations to be added to the service             | `{}`          |
| `dex.service.type`                           | Service type for Dex                               | `ClusterIP`   |
| `dex.service.clusterIP`                      | Internal cluster service IP for Dex                | `""`          |
| `dex.service.ports.http.port`                | HTTP service port for Dex                          | `5556`        |
| `dex.service.ports.http.nodePort`            | HTTP node port for Dex (if applicable)             | `""`          |
| `dex.service.ports.https.port`               | HTTPS service port for Dex                         | `5554`        |
| `dex.service.ports.https.nodePort`           | HTTPS node port for Dex (if applicable)            | `""`          |
| `dex.service.ports.grpc.port`                | gRPC service port for Dex                          | `5557`        |
| `dex.service.ports.grpc.nodePort`            | gRPC node port for Dex (if applicable)             | `""`          |
| `dex.ingress.enabled`                        | Enable ingress for Dex                             | `false`       |
| `dex.ingress.className`                      | Ingress class name for Dex                         | `""`          |
| `dex.ingress.annotations`                    | Annotations to be added to the ingress             | `{}`          |
| `dex.ingress.hosts`                          | Ingress host configuration for Dex                 | `[{ host: chart-example.local, paths: [{ path: /, pathType: ImplementationSpecific }] }]` |
| `dex.ingress.tls`                            | Ingress TLS configuration for Dex                  | `[]`          |
| `dex.serviceMonitor.enabled`                 | Enable Prometheus ServiceMonitor for Dex           | `false`       |
| `dex.serviceMonitor.namespace`               | Namespace for ServiceMonitor resource              | `""`          |
| `dex.serviceMonitor.interval`                | Prometheus scrape interval for ServiceMonitor      | `""`          |
| `dex.serviceMonitor.scrapeTimeout`           | Prometheus scrape timeout for ServiceMonitor       | `""`          |
| `dex.serviceMonitor.labels`                  | Labels to be added to ServiceMonitor               | `{}`          |
| `dex.serviceMonitor.annotations`            | Annotations to be added to ServiceMonitor           | `{}`          |
| `dex.serviceMonitor.scheme`                  | HTTP scheme to use for scraping in ServiceMonitor  | `""`          |
| `fulcio.namespace.create`                           | Whether to create the Fulcio namespace                | `false`                                                                   |
| `fulcio.namespace.name`                             | Name of the Fulcio namespace if created               | `fulcio-system`                                                           |
| `fulcio.imagePullSecrets`                           | Secrets to pull the Fulcio image                      | `[]`                                                                      |
| `fulcio.config.contents`                            | Contents of Fulcio configuration                      | `{}`                                                                      |
| `fulcio.server.replicaCount`                        | Number of replicas for Fulcio server                  | `1`                                                                       |
| `fulcio.server.name`                                | Name of the Fulcio server                             | `server`                                                                  |
| `fulcio.server.svcPort`                             | Service port for Fulcio server                        | `80`                                                                      |
| `fulcio.server.grpcSvcPort`                         | gRPC service port for Fulcio server                   | `5554`                                                                    |
| `fulcio.server.secret`                              | Secret for Fulcio server                              | `fulcio-server-secret`                                                    |
| `fulcio.server.logging.production`                  | Whether production logging is enabled for Fulcio      | `false`                                                                   |
| `fulcio.server.image.registry`                      | Registry for Fulcio server image                      | `gcr.io`                                                                  |
| `fulcio.server.image.repository`                    | Repository for Fulcio server image                    | `projectsigstore/fulcio`                                                  |
| `fulcio.server.image.pullPolicy`                    | Pull policy for Fulcio server image                   | `IfNotPresent`                                                            |
| `fulcio.server.image.version`                       | Version/tag for Fulcio server image                   | `sha256:d4e075bfaf0539a5220f3a76b80454261ecda443248fce283fd185d27e9910d4` |
| `fulcio.server.args.port`                           | Port for Fulcio server                                | `5555`                                                                    |
| `fulcio.server.args.grpcPort`                       | gRPC port for Fulcio server                           | `5554`                                                                    |
| `fulcio.server.args.certificateAuthority`           | Certificate authority for Fulcio server               | `fileca`                                                                  |
| `fulcio.server.args.hsm_caroot_id`                  | HSM CA root ID for Fulcio server                      |                                                                           |
| `fulcio.server.args.aws_hsm_root_ca_path`           | AWS HSM root CA path for Fulcio server                |                                                                           |
| `fulcio.server.args.gcp_private_ca_parent`          | GCP private CA parent for Fulcio server               | `projects/test/locations/us-east1/caPools/test`                          |
| `fulcio.server.args.ct_log_url`                     | URL for CT log for Fulcio server                      |                                                                           |
| `fulcio.server.args.disable_ct_log`                 | Whether CT log is disabled for Fulcio server          | `false`                                                                   |
| `fulcio.server.serviceAccount.create`               | Whether to create a service account for Fulcio server | `true`                                                                    |
| `fulcio.server.serviceAccount.name`                 | Name of the service account for Fulcio server         |                                                                           |
| `fulcio.server.serviceAccount.annotations`          | Annotations for the Fulcio server service account     | `{}`                                                                      |
| `fulcio.server.serviceAccount.mountToken`           | Whether to mount token for Fulcio server service account | `true`                                                                |
| `fulcio.server.service.type`                        | Service type for Fulcio server                        | `ClusterIP`                                                               |
| `fulcio.server.service.ports`                       | Ports for Fulcio server service                       | `http: 80, grpc: 5554, 2112-tcp: 2112`                                   |
| `fulcio.server.ingress.http.enabled`                | Whether HTTP ingress is enabled for Fulcio server     | `true`                                                                    |
| `fulcio.server.ingress.http.className`              | Ingress class for HTTP for Fulcio server              | `"nginx"`                                                                 |
| `fulcio.server.ingress.http.annotations`            | Annotations for HTTP ingress for Fulcio server        | `{}`                                                                      |
| `fulcio.server.ingress.http.hosts`                  | Hosts for HTTP ingress for Fulcio server              | `[{path: "/", host: "fulcio.localhost"}]`                                |
| `fulcio.server.ingress.http.tls`                    | TLS configuration for HTTP ingress for Fulcio server  | `[]`                                                                      |
| `fulcio.server.ingress.grpc.enabled`                | Whether gRPC ingress is enabled for Fulcio server     | `false`                                                                   |
| `fulcio.server.ingress.grpc.className`              | Ingress class for gRPC for Fulcio server              |                                                                           |
| `fulcio.server.ingress.grpc.annotations`            | Annotations for gRPC ingress for Fulcio server        | `{nginx.ingress.kubernetes.io/backend-protocol: "GRPC"}`                  |
| `fulcio.server.ingress.grpc.hosts`                  | Hosts for gRPC ingress for Fulcio server              | `[{host: fulcio.localhost, path: /dev.sigstore.fulcio.v2.CA}]`            |
| `fulcio.server.ingress.grpc.tls`                    | TLS configuration for gRPC ingress for Fulcio server  | `[{secretName: fulcio-grpc-ingress-tls, hosts: [fulcio.localhost]}]`      |
| `fulcio.server.ingresses`                           | List of additional ingresses for Fulcio server        | `[{enabled: false, grpc: true, http: true, name: "gce-ingress", className: "gce", ...}]` |
| `fulcio.server.securityContext.runAsNonRoot`        | Whether to run Fulcio server as non-root               | `true`                                                                    |
| `fulcio.server.securityContext.runAsUser`           | User ID for running Fulcio server                      | `65533`                                                                   |
| `fulcio.createcerts.enabled`                        | Whether to enable creation of certificates            | `true`                                                                    |
| `fulcio.createcerts.replicaCount`                   | Number of replicas for certificate creation           | `1`                                                                       |
| `fulcio.createcerts.name`                           | Name of the certificate creation component            | `createcerts`                                                             |
| `fulcio.createcerts.image.registry`                 | Registry for certificate creation image               | `ghcr.io`                                                                 |
| `fulcio.createcerts.image.repository`               | Repository for certificate creation image             | `sigstore/scaffolding/createcerts`                                        |
| `fulcio.createcerts.image.pullPolicy`               | Pull policy for certificate creation image            | `IfNotPresent`                                                            |
| `fulcio.createcerts.image.version`                  | Version/tag for certificate creation image            | `sha256:2aaea38198d25ee53fb1f6da79eaa75c24bcc4ef81792a68687ba2ae0dc8ccf6` |
| `fulcio.createcerts.ttlSecondsAfterFinished`        | Time to live for the job after completion             |                                                                           |
| `kratos.replicaCount`                                 | Number of replicas in deployment                                                      | `1`                                                        |
| `kratos.strategy.type`                                | Deployment update strategy type                                                       | `RollingUpdate`                                            |
| `kratos.strategy.rollingUpdate.maxSurge`              | The max surge for rolling update                                                      | `25%`                                                      |
| `kratos.strategy.rollingUpdate.maxUnavailable`        | The max unavailable for rolling update                                                | `25%`                                                      |
| `kratos.image.repository`                             | ORY KRATOS image repository                                                           | `ghcr.io/testifysec/kratos`                                |
| `kratos.image.tag`                                    | ORY KRATOS version tag                                                                | `v1.0.0-token-update`                                      |
| `kratos.image.pullPolicy`                             | Image pull policy                                                                     | `IfNotPresent`                                             |
| `kratos.imagePullSecrets`                         | Specify docker-registry secret names as an array                                      | `[]`                                                       |
| `kratos.nameOverride`                               | String to partially override kratos.fullname template with a string                   | ``                                                         |
| `kratos.fullnameOverride`                           | String to fully override kratos.fullname template with a string                       | `"kratos"`                                                 |
| `kratos.service.admin.enabled`                     | Enable admin service                                                                  | `true`                                                     |
| `kratos.service.admin.type`                        | Admin service type                                                                    | `ClusterIP`                                                |
| `kratos.service.admin.port`                        | Admin service port                                                                    | `80`                                                       |
| `kratos.service.admin.name`                        | Admin service port name                                                               | `http`                                                     |
| `kratos.service.admin.metricsPath`                 | Path to the admin metrics endpoint                                                    | `/admin/metrics/prometheus`                                |
| `kratos.service.public.enabled`                    | Enable public service                                                                 | `true`                                                     |
| `kratos.service.public.type`                       | Public service type                                                                   | `ClusterIP`                                                |
| `kratos.service.public.port`                       | Public service port                                                                   | `80`                                                       |
| `kratos.service.public.name`                       | Public service port name                                                              | `http`                                                     |
| `kratos.ingress.public.enabled`                    | Enable public ingress                                                                 | `true`                                                     |
| `kratos.ingress.public.className`                  | Public ingress class name                                                             | `nginx`                                                    |
| `kratos.ingress.public.hosts[0].host`              | Host for public ingress                                                               | `kratos.testifysec.localhost`                              |
| `kratos.ingress.public.hosts[0].paths[0].path`     | Path for public ingress                                                               | `/`                                                        |
| `kratos.ingress.public.tls[0].secretName`          | TLS secret name for public ingress                                                    | `kratos-tls-secret`                                        |
| `kratos.kratos.development`           | Enable development mode for Kratos                                                    | `false`                                                    |
| `kratos.kratos.dsn`                    | DSN for connecting to the database                                                    | `mysql://root:root@tcp(judge-mysql.judge.svc.cluster.local:3306)/kratos` |
| `kratos.kratos.config.serve.admin.port` | Port for Kratos admin service                                                         | `4433`                                                     |
| `kratos.kratos.config.serve.public.port` | Port for Kratos public service                                                        | `4434`                                                     |
| `kratos.kratos.config.serve.public.base_url` | Base URL for the public service                                                      | `https://kratos.testifysec.localhost`                      |
| `kratos.kratos.config.log.level`         | Log level                                                                            | `debug`                                                    |
| `kratos.kratos.config.selfservice.flows.login.ui_url` | UI URL for the login flow                                                           | `https://login.testifysec.localhost/login`                 |
| `kratos.kratos.config.methods.password.enabled` | Enable password method for authentication                                            | `false`                                                    |
| `kratos.kratos.config.methods.oidc.enabled` | Enable OpenID Connect method for authentication                                      | `true`                                                     |
| `kratos.kratos.secrets`                  | Secrets used by Kratos                                                                | `{}`                                                       |
| `kratos.kratos.config.serve.admin.base_url`                      | The base URL to access the admin service                                      | `https://kratos-admin.testifysec.localhost`    |
| `kratos.kratos.config.serve.admin.port`                           | The port for the Kratos admin service                                          | `4433`                                   |
| `kratos.kratos.config.serve.public.port`                          | The port for the Kratos public service                                         | `4434`                                   |
| `kratos.kratos.config.serve.public.base_url`                      | The base URL to access the public service                                      | `https://kratos.testifysec.localhost`    |
| `kratos.kratos.config.serve.public.cors.enabled`                  | Enable CORS support                                                            | `true`                                   |
| `kratos.kratos.config.serve.public.cors.allowed_origins`          | Origins allowed to perform CORS requests                                       | `[ "https://*.testifysec.localhost:8077" ]` |
| `kratos.kratos.config.serve.public.cors.allowed_methods`          | HTTP methods allowed for CORS requests                                         | `[ "POST", "GET", "PUT", "PATCH", "DELETE" ]` |
| `kratos.kratos.config.serve.public.cors.allowed_headers`          | Headers that can be used when making a request                                 | `[ "Authorization", "Cookie", "Content-Type" ]` |
| `kratos.kratos.config.serve.public.cors.exposed_headers`          | Headers that are safe to expose to the API of a CORS API specification         | `[ "Content-Type", "Set-Cookie" ]`       |
| `kratos.kratos.config.log.level`                                  | The log level (e.g., info, warn, debug)                                        | `debug`                                  |
| `kratos.kratos.config.log.format`                                 | The log format (e.g., json)                                                     | `json`                                   |
| `kratos.kratos.config.log.leak_sensitive_values`                  | Option to leak sensitive values in the logs                                     | `true`                                   |
| `kratos.kratos.config.selfservice.flows.login.ui_url`             | The user interface URL for the login page                                       | `https://login.testifysec.localhost/login` |
| `kratos.kratos.config.selfservice.flows.error.ui_url`             | The user interface URL for the error page                                       | `https://login.testifysec.localhost/error` |
| `kratos.kratos.config.selfservice.flows.settings.ui_url`          | The user interface URL for the settings page                                    | `http://login.testifysec.localhost/settings` |
| `kratos.kratos.config.selfservice.flows.recovery.enabled`         | Enable the recovery flow                                                       | `true`                                   |
| `kratos.kratos.config.selfservice.flows.recovery.ui_url`          | The user interface URL for the recovery page                                    | `https://login.testifysec.localhost/recovery` |
| `kratos.kratos.config.selfservice.flows.verification.enabled`     | Enable the verification flow                                                    | `true`                                   |
| `kratos.kratos.config.selfservice.flows.verification.ui_url`      | The user interface URL for the verification page                                | `https://login.testifysec.localhost/verification` |
| `kratos.kratos.config.selfservice.flows.registration.ui_url`      | The user interface URL for the registration page                                | `https://login.testifysec.localhost/registration` |
| `kratos.kratos.config.selfservice.flows.logout.after.default_browser_return_url` | Default return URL after logout                                  | `https://login.testifysec.localhost/login` |
| `kratos.kratos.config.selfservice.methods.password.enabled`       | Enable password authentication method                                           | `false`                                  |
| `kratos.kratos.config.selfservice.methods.oidc.enabled`           | Enable OIDC authentication method                                               | `true`                                   |
| `kratos.kratos.config.identity.default_schema_id`                 | The default identity schema ID                                                  | `default`                                |
| `kratos.kratos.config.courier.smtp.connection_uri`                | SMTP connection URI for sending emails                                          | `smtps://dummy`                          |
| `kratos.kratos.config.cookies.domain`                             | The domain scope for cookies                                                    | `testifysec.localhost`                  |
| `kratos.kratos.config.cookies.path`                               | The path scope for cookies                                                      | `/`                                      |
| `kratos.kratos.config.cookies.same_site`                          | SameSite attribute for cookies                                                  | `Lax`                                    |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].id`    | Identifier for the authentication provider                              | `gitlab`                                      |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].provider` | The name of the identity provider                                       | `gitlab`                                      |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].client_id` | The client ID obtained from GitLab for OIDC authentication              | `YOUR_GITLAB_CLIENT_ID`                       |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].client_secret` | The client secret obtained from GitLab                                  | `YOUR_GITLAB_CLIENT_SECRET`                   |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].issuer_url` | The issuer URL for GitLab's OIDC endpoint                                | `https://gitlab.com`                          |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].scope` | Scopes requested from GitLab during authentication                      | `[ "openid", "profile", "email" ]`            |
| `kratos.kratos.config.selfservice.methods.oidc.config.providers[].mapper_url` | URL to the Jsonnet file for mapping GitLab user info to Kratos identities | `file:///etc/config/kratos/gitlab.jsonnet`    |
| `minio.replicaCount`                         | Number of Minio replicas                                    | `1`                                                                   |
| `minio.image.registry`                       | The domain of the Minio OCI image registry                  | `quay.io`                                                             |
| `minio.image.repository`                     | Minio image repository                                      | `minio/minio`                                                         |
| `minio.image.tag`                            | Tag of the Minio image                                      | `latest`                                                              |
| `minio.initMinioBucket.enabled`              | Specifies if Minio bucket initialization is enabled         | `true`                                                                |
| `minio.mc.nameOverride`                      | Specified the `mc` image name override                      | `""`                                                                  |
| `minio.service.type`                         | Service type for Minio                                      | `ClusterIP`                                                           |
| `minio.service.port`                         | Port for Minio service                                      | `9000`                                                                |
| `minio.ingress.enabled`                      | Specifies if Ingress is enabled for Minio                   | `false`                                                               |
| `minio.ingress.hosts[0].host`                | Hostname for Minio Ingress                                  | `minio.testifysec.local`                                              |
| `minio.resources`                            | Resources for Minio Deployment                              | `{}` (unspecified, user-defined)                                      |
| `minio.autoscaling.enabled`                  | Specifies if autoscaling is enabled for Minio               | `false`                                                               |
| `minio.autoscaling.minReplicas`              | Minimum replicas for autoscaling                            | `1`                                                                   |
| `minio.autoscaling.maxReplicas`              | Maximum replicas for autoscaling                            | `100`                                                                 |
| `minio.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling     | `80`                                                                  |
| `minio.volumes`                              | Additional volumes for Minio Deployment                     | `- name: archivista emptyDir: {}` (unspecified, user-defined)         |
| `minio.volumeMounts`                         | Additional volume mounts for Minio Deployment               | `- name: archivista mountPath: "/data" readOnly: false` (unspecified, user-defined) |
| `minio.nodeSelector`                         | Node selector for Minio pods                                | `{}` (unspecified, user-defined)                                      |
| `minio.tolerations`                          | Tolerations for Minio pods                                  | `[]` (unspecified, user-defined)                                      |
| `minio.affinity`                             | Affinity settings for Minio pods                            | `{}` (unspecified, user-defined)                                      |
| `minio.selectorLabels.app`                   | Selector labels for Minio pods                              | `app: minio` (unspecified, user-defined)                              |
| `mysql.mysqlRootPassword`                    | Root password for MySQL                                     | `"root"`                                                              |
| `mysql.image.tag`                            | Tag of the MySQL image                                      | `latest`                                                              |
| `mysql.imagePullSecrets`                     | Secrets to pull the MySQL image                             | `[]`                                                                  |
| `tsa.namespace.create`                       | Specifies whether to create a namespace for TSA      | `false`     |
| `tsa.namespace.name`                         | Name of the TSA namespace                           | `tsa-system` |
| `tsa.server.replicaCount`                    | Number of TSA server replicas                       | `1`         |
| `tsa.server.name`                            | Name of the TSA server                              | `server`    |
| `tsa.server.svcPort`                         | Service port for TSA                                | `80`        |
| `tsa.server.grpcSvcPort`                     | gRPC service port for TSA                           | `5554`      |
| `tsa.server.secret`                          | Secret for TSA server                               | `tsa-server-secret` |
| `tsa.server.logging.production`              | Specifies production logging for TSA server         | `false`     |
| `tsa.server.env.GOOGLE_APPLICATION_CREDENTIALS` | Google Application Credentials for TSA server    | `/etc/tsa-config/cloud_credentials` |
| `tsa.server.image.registry`                  | Registry for TSA server image                       | `ghcr.io`   |
| `tsa.server.image.repository`                | Repository for TSA server image                     | `sigstore/timestamp-server` |
| `tsa.server.image.pullPolicy`                | Pull policy for TSA server image                    | `IfNotPresent` |
| `tsa.server.image.version`                   | Version of TSA server image                         | `sha256:f4dcc96092a1b1fb5ca36d776f92a7cc62cdb1a8866c5120340f919141a3cd58` |
| `tsa.server.args.port`                       | Port for TSA server                                 | `5555`      |
| `tsa.server.args.signer`                     | Signer type for TSA server                          | `tink`      |
| `tsa.server.args.cert_chain`                 | PEM encoded cert chain for TSA server               | `chain`     |
| `tsa.server.args.tink_enc_keyset`            | Tink encryption keyset for TSA server               | `keyset`    |
| `tsa.server.args.tink_key_resource`          | Tink key resource for TSA server                    | `resource`  |
| `tsa.server.args.tink_hcvault_token`         | Tink Hashicorp Vault token for TSA server           | `token`     |
| `tsa.server.args.kms_key_resource`           | KMS key resource for TSA server                     | `resource`  |
| `tsa.server.serviceAccount.create`           | Specifies whether to create a service account for TSA server | `true` |
| `tsa.server.serviceAccount.name`             | Name of the service account for TSA server          | `""` (empty, unspecified) |
| `tsa.server.serviceAccount.annotations`      | Annotations for the service account for TSA server  | `{}`        |
| `tsa.server.serviceAccount.mountToken`       | Specifies whether to mount a token for TSA server  | `true`      |
| `tsa.server.service.type`                    | Service type for TSA server                         | `ClusterIP` |
| `tsa.server.service.ports`                   | Ports for TSA server service                        | See below   |
| `tsa.server.ingress.http.enabled`            | Specifies whether HTTP ingress is enabled for TSA server | `true` |
| `tsa.server.ingress.http.className`          | Ingress class for HTTP ingress of TSA server        | `"nginx"`   |
| `tsa.server.ingress.http.annotations`        | Annotations for HTTP ingress of TSA server          | `{}`        |
| `tsa.server.ingress.http.hosts`              | Hosts for HTTP ingress of TSA server                | See below   |
| `tsa.server.ingress.http.tls`                | TLS configuration for HTTP ingress of TSA server    | `[]`        |
| `tsa.server.securityContext.runAsNonRoot`    | Specifies whether to run TSA server as non-root     | `true`      |
| `tsa.server.securityContext.runAsUser`       | User ID to run TSA server as                        | `65533`     |
| `tsa.forceNamespace`                         | Force namespace for namespaced resources            | `""` (empty, unspecified) |

You can override these values either directly using `--set` during installation or by specifying them in a separate YAML file with `-f`. Adjust these values according to your deployment requirements to optimize the behavior of JUDGE as per your needs.
