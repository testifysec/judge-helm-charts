# JUDGE-Web Documentation

Welcome to the documentation for JUDGE-Web, the user interface component of the JUDGE SaaS platform. This documentation provides an overview of JUDGE-Web, its features, installation instructions, and usage guidelines.

## Overview

JUDGE-Web is the front-facing interface that allows users to interact with the JUDGE SaaS platform. It provides an intuitive and user-friendly interface for accessing and managing various features and functionalities offered by our platform.

JUDGE-Web provides a comprehensive and user-friendly interface for accessing and managing the features and functionalities of our SaaS platform. By following the installation instructions and usage guidelines provided in this documentation, you can effectively leverage JUDGE-Web to streamline your workflow and enhance your productivity.

## JUDGE Web Reverse Proxies

In the JUDGE web application, reverse proxies play a crucial role in managing and redirecting traffic to the underlying stack. They provide a convenient mechanism for routing requests without the need to configure Cross-Origin Resource Sharing (CORS) headers explicitly. This document explains the purpose of reverse proxies in JUDGE web, how they work, and provides guidance on customization to suit specific deployment needs, including integration with custom ingress controller solutions.

### Purpose

The primary purpose of reverse proxies in the JUDGE web application is to:

1. **Redirect Traffic**: Reverse proxies facilitate the redirection of incoming HTTP requests to different backend services based on predefined rules. This redirection ensures that requests are efficiently routed to the appropriate endpoints within the application stack.

2. **Manage CORS**: By serving as an intermediary between the client and the backend services, reverse proxies help manage Cross-Origin Resource Sharing (CORS) policies. They enable seamless communication between frontend components and backend APIs by handling CORS-related issues transparently.

### How It Works

In the JUDGE web application, reverse proxies are configured using Kubernetes Ingress resources. These resources define rules for routing incoming requests to specific backend services based on the requested URL paths. Additionally, annotations within the Ingress configuration provide additional instructions for the reverse proxy behavior.

#### Key Components

- **Ingress**: Kubernetes Ingress resources define the routing rules and configurations for the reverse proxies.
- **Annotations**: Annotations within the Ingress configuration provide additional instructions to the reverse proxy, such as SSL redirection, rewrite rules, and CORS handling.

### Customization

You may need to customize the reverse proxies in JUDGE web to align with your specific deployment requirements or integrate with your existing ingress controller solutions. The following are some customization options:

1. **URL Path Routing**: Modify the URL path routing rules to direct traffic to different backend services based on specific URL patterns. This customization allows for flexible routing of requests within the application.

2. **Annotations Configuration**: Adjust the annotations within the Ingress configuration to modify reverse proxy behavior. You can enable or disable features such as SSL redirection, rewrite rules, and CORS handling based on your requirements.

3. **Integration with Custom Ingress Controllers**: Your existing ingress controller solutions can integrate the JUDGE web reverse proxies with your controller by ensuring compatibility with the controller's configuration format and capabilities.

### Configuration Example

Below is an example of the configuration for reverse proxies in the JUDGE web application, specified in the `values.yaml` file:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    # Add annotations here for SSL redirection, rewrite rules, etc.
  hosts:
    - host: "judge.testifysec.localhost"
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: judge-web
              port:
                number: 8077
```

You can customize the `annotations` section and URL path routing rules (`paths`) to tailor the reverse proxy configuration according to your deployment needs.

For more information, see [Configuring JUDGE](./configuring-judge-helm.md).

### Conclusion

Reverse proxies play a crucial role in managing traffic redirection and CORS handling in the JUDGE web application. By understanding your purpose, functionality, and customization options, customers can effectively leverage reverse proxies to optimize your deployment and ensure seamless communication between frontend and backend components.