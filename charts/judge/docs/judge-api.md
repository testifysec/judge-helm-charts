# JUDGE API Overview and Configuration Guide

The JUDGE API serves as a crucial component of our SaaS platform, providing GraphQL and REST endpoints for various functionalities. This document provides an overview of the JUDGE API's capabilities and explains how to configure it using environment variables.

## Functionality

The JUDGE API facilitates the following key functionalities within our platform:

1. **GraphQL and REST Endpoints**: The API offers GraphQL and REST endpoints, allowing clients to interact with our platform programmatically.

2. **Integration with Kratos**: JUDGE API seamlessly integrates with Kratos, our authentication solution. Kratos handles user authentication and management, ensuring secure access to platform resources.

3. **Integration with Git Providers**: JUDGE API supports integration with popular Git providers such as GitLab and GitHub. This integration enables seamless interaction with Git repositories, facilitating version control and collaboration.

4. **Integration with Archivista**: Our platform includes an open-source GraphQL attestation store called Archivista. JUDGE API integrates with Archivista, allowing users to store and retrieve attestations securely.

## Configuration

To configure the JUDGE API for your environment, you can use environment variables provided in the deployment configuration. These variables allow you to customize the integration with Kratos:

```yaml
deployment:
  env:
    - name: KRATOS_PUBLIC_URL
      value: "kratos-public.default.svc.cluster.local"
    - name: KRATOS_ADMIN_URL
      value: "kratos-admin.default.svc.cluster.local"
```

Here's what each environment variable does:

- **`KRATOS_PUBLIC_URL`**: Specifies the URL of the Kratos public service. This URL is used by the JUDGE API to communicate with Kratos for user authentication and access management.

- **`KRATOS_ADMIN_URL`**: Specifies the URL of the Kratos admin service. This URL is used for administrative tasks related to user management and configuration.

If you decide to customize the namespace or service name for the Kratos deployment in your Kubernetes cluster, you'll need to update these environment variables accordingly to ensure seamless integration with JUDGE API.

For more information, see [Configuring JUDGE](./configuring-judge-helm.md).

## Conclusion

The JUDGE API plays a critical role in our SaaS platform, providing essential endpoints for interacting with platform services. By configuring the environment variables described above, you can tailor the integration with Kratos to suit your environment's specific requirements. If you have any questions or need further assistance with configuring the JUDGE API, please don't hesitate to reach out to our support team for guidance.