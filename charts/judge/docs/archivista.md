# Archivista Service Configuration Guide

The Archivista service is a component of our platform that provides a GraphQL interface and storage backend for managing attestations. This document outlines the key configuration options available in the `values.yaml` file for deploying the Archivista service using Helm.

## Configuration Options

### `deployment.env`

- **Description:** Specifies environment variables used by the Archivista service.
  - `ARCHIVISTA_ENABLE_SPIFFE`: Indicates whether SPIFFE authentication is enabled. Set to `"False"`.
  - `ARCHIVISTA_LISTEN_ON`: Specifies the network interface and port on which Archivista listens for incoming connections.
  - `ARCHIVISTA_STORAGE_BACKEND`: Defines the storage backend used by Archivista. Set to `"BLOB"`.
  - `ARCHIVISTA_BLOB_STORE_USE_TLS`: Indicates whether TLS is used for communication with the blob store. Set to `"False"`.
  - `ARCHIVISTA_BLOB_STORE_ACCESS_KEY_ID`: Access key ID for accessing the blob store.
  - `ARCHIVISTA_BLOB_STORE_SECRET_ACCESS_KEY_ID`: Secret access key ID for accessing the blob store.
  - `ARCHIVISTA_BLOB_STORE_BUCKET_NAME`: Name of the bucket in the blob store.
  - `ARCHIVISTA_BLOB_STORE_ENDPOINT`: Endpoint of the blob store.
  - `ARCHIVISTA_ENABLE_GRAPHQL`: Specifies whether the GraphQL interface is enabled. Set to `"true"`.
  - `ARCHIVISTA_GRAPHQL_WEB_CLIENT_ENABLE`: Indicates whether the GraphQL web client is enabled. Set to `"true"`.
  - `ARCHIVISTA_CORS_ALLOW_ORIGINS`: Defines the allowed origins for Cross-Origin Resource Sharing (CORS). Set to `"*"`.
  - `MYSQLPASS`: Password for accessing the MySQL database.
  - `ARCHIVISTA_SQL_STORE_CONNECTION_STRING`: Connection string for the MySQL database.

### `service`

- **Description:** Specifies the Kubernetes service configuration for the Archivista service.
  - `type`: Defines the type of Kubernetes service. Set to `"ClusterIP"`.
  - `port`: Specifies the port on which the service listens.

### `ingress`

- **Description:** Configures Ingress settings for exposing the Archivista service externally.
  - `enabled`: Indicates whether Ingress is enabled.
  - `hosts`: Specifies the hostnames and paths for routing traffic to the Archivista service.

### `autoscaling`

- **Description:** Configures horizontal pod autoscaling for the Archivista service.
  - `enabled`: Indicates whether autoscaling is enabled.
  - `minReplicas`: Specifies the minimum number of replicas.
  - `maxReplicas`: Specifies the maximum number of replicas.
  - `targetCPUUtilizationPercentage`: Sets the target CPU utilization percentage for scaling.

For more information, see [Configuring JUDGE](./configuring-judge-helm.md).

## Conclusion

By understanding and configuring these key options in the `values.yaml` file, you can deploy and customize the Archivista service according to your requirements. If you need further assistance or have specific customization needs, feel free to reach out to our support team for guidance.