# Kratos Container Configuration Guide

The Kratos service serves as the authentication solution for JUDGE, seamlessly integrating with various OIDC providers like GitHub and GitLab. This document provides instructions on configuring Kratos and setting up integrations with GitLab and GitHub.

## Ingress Configuration

Kratos exposes two ingress endpoints, one for administrative purposes and the other for public access:

### Public Ingress

- **Host:** kratos.testifysec.localhost
- **TLS Configuration:** Uses the `kratos-tls-secret` for HTTPS encryption

### Admin Ingress

- **Host:** kratos.admin.local.com
- **TLS Configuration:** Not enabled by default

## Application-Specific Configuration

Kratos offers various configuration options tailored to different use cases and environments. Below are the key configuration parameters:

### Database Configuration

- **DSN:** Specifies the database connection string for Kratos.
- **Automigration:** Controls database schema initialization and migration.

### Identity Schemas

You can define multiple identity schemas to customize user attributes and validation rules.

### Email Templates

Customize the content of emails sent by Kratos for actions like account recovery and verification.

### Serve Configuration

Configures the ports and base URL for serving Kratos endpoints, along with CORS settings.

### Self-Service Flows

Defines URLs and behavior for user self-service actions like account recovery and verification.

### OIDC Methods Configuration

Enables OIDC authentication methods and configures providers like GitHub and GitLab.

## Integrating with GitLab and GitHub

To integrate Kratos with GitLab and GitHub, you'll need to generate application IDs and keys for JUDGE. Here's how:

1. **GitHub Integration**:
   - Log in to your GitHub account.
   - Go to Settings > Developer settings > OAuth Apps.
   - Click on "New OAuth App" and fill in the required details.
   - Set the Authorization callback URL to your Kratos svc, for example `https://kratos.testifysec.localhost/selfservice/methods/oidc/callback/github`.
   - After creating the app, note down the Client ID and Client Secret.
   - Update the Kratos configuration with these values for the GitHub provider.

2. **GitLab Integration**:
   - Log in to your GitLab account.
   - Go to Settings > Applications.
   - Create a new application and fill in the required details.
   - Set the Redirect URI to your Kratos svc, for example `https://kratos.testifysec.localhost/selfservice/methods/oidc/callback/gitlab`.
   - Once created, obtain the Application ID and Secret.
   - Update the Kratos configuration with these values for the GitLab provider.

After generating your secret(s), in your values.yaml define:

```yaml
kratos:
  kratos:
    config:
      selfservice:
        allowed_return_urls:
          - https://login.testifysec.localhost
          - https://kratos.testifysec.localhost
          - https://judge.testifysec.localhost
          - https://localhost
          - https://judge.testifysec.localhost:8077

        methods:
          oidc:
            config:
              providers:
                - id: github
                  provider: github
                  client_id: your-github-client-id
                  client_secret: your-github-client-secret
                  issuer_url: https://github.com
                  mapper_url: file:///etc/config/kratos/github.jsonnet
                  scope:
                    - user
                  # -and/or 
                - id: gitlab
                  provider: gitlab
                  client_id: your-gitlab-client-id
                  client_secret: your-gitlab-client-secret
                  issuer_url: https://gitlab.com
                  mapper_url: file:///etc/config/kratos/gitlab.jsonnet
                  scope:
                    - openid
                    - profile
                    - email
                    - read_user
                    - read_api
                    - read_repository
```

For more information, see [Configuring JUDGE](./configuring-judge-helm.md).

## Conclusion

Configuring Kratos with OIDC providers like GitHub and GitLab enables seamless authentication for users accessing our platform. By following the steps outlined above, you can set up Kratos to integrate with your preferred identity providers and customize its behavior to meet your specific requirements. If you encounter any issues or need further assistance, feel free to reach out to our support team for help.