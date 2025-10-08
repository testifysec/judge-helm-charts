# Kratos Self-Service UI Node Configuration Guide

The Kratos Self-Service UI Node serves as the user interface component of our authentication solution. It provides UI components for user authentication workflows such as login, logout, signup, password reset, and user details management. This document explains the key configuration values in the `values.yaml` file for the Kratos Self-Service UI Node Helm chart.

## Configuration Values

### `kratosAdminUrl`

- **Description:** Specifies the URL of the ORY Kratos Admin API.
- **Value:** `http://kratos-admin`
- **Usage:** This URL is used by the UI node to communicate with the Kratos Admin API for administrative tasks and user management operations.

### `kratosPublicUrl`

- **Description:** Specifies the URL of the ORY Kratos Public API.
- **Value:** `http://kratos-public`
- **Usage:** The UI node uses this URL to interact with the Kratos Public API for user authentication and self-service operations.

### `kratosBrowserUrl`

- **Description:** Specifies the URL of the ORY Kratos Public API accessible from the outside world.
- **Value:** `http://kratos.testifysec.localhost`
- **Usage:** This URL represents the external-facing endpoint of the Kratos Public API, accessible to users accessing the authentication UI from the browser. It is used to construct links and redirects for user authentication flows and redirects back to the application after completion.

For more information, see [Configuring JUDGE](./configuring-judge-helm.md).

## Conclusion

Understanding and configuring these key values in the `values.yaml` file ensures proper communication between the Kratos Self-Service UI Node and the underlying ORY Kratos APIs. By setting the correct URLs for the Kratos Admin, Public, and browser-facing endpoints, you can ensure seamless user authentication and self-service experiences within your application. If you have any questions or need further assistance with configuring the Kratos Self-Service UI Node, don't hesitate to reach out to our support team for help.