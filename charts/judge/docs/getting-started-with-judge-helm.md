# Getting Started

The JUDGE stack comprises several components that work together to provide a comprehensive solution for attestation, policy management, and governance services. This guide outlines the setup process for deploying and configuring the JUDGE stack, including JUDGE-web, JUDGE-api, Archivista, databases, and object storage, along with authentication configuration using GitLab or GitHub.

## Components of the JUDGE Stack

1. **JUDGE-web**: Primary web UI for JUDGE.
2. **JUDGE-api**: Primary API for JUDGE.
3. **Archivista**: Attestation, policy, and VSA GraphQL store for JUDGE.
4. **Database**: MySQL, PostgreSQL, etc., required for storing data. Databases needed:
   - `archivista`
   - `kratos`
   - `judgeapi`
5. **Simple Object Storage**: Minio, Amazon S3, etc., used for object storage in Archivista.
6. **Auth**: JUDGE uses Kratos to assist with auth using your favorite OIDC providers.

## Setup Instructions

JUDGE requires Database and Object storage, which you should provision and configure for JUDGE.

This guide will walk you through what is needed for JUDGE to get to work for you.

### 1. Database Configuration

- Create databases `archivista`, `kratos`, and `judgeapi` on your chosen database server.
- Execute the following SQL commands to create the databases:

  ```sql
  CREATE DATABASE IF NOT EXISTS archivista;
  CREATE DATABASE IF NOT EXISTS kratos;
  CREATE DATABASE IF NOT EXISTS judgeapi;
  ```
  
- Ensure you have the connection strings for the databases.

### 2. Object Storage Configuration

- Set up Simple Object Storage (Minio, S3, etc.).
- Configure the object storage with the necessary buckets and permissions for JUDGE to read and write to it.

### 3. Helm Values Configuration

- Configure Helm values to specify the connection strings to the databases for Archivista, Kratos, and JUDGE-api.
- For more information, see [Configuring Judge Helm](./configuring-judge-helm.md)

### 4. Environment Variable Configuration for Archivista

- Set environment variables for Archivista to connect to the object storage.
- Ensure Archivista has the necessary environment variables configured to interact with the chosen object storage solution.
- For more information, see [Configuring Judge Helm](./configuring-judge-helm.md)

### 5. Authentication Configuration

- Generate an application ID and secret from your preferred GitLab or GitHub instance.
- Provide the generated application ID and secret to JUDGE for authentication capabilities.
- Configure the authentication settings in `Kratos` to use the generated credentials for GitLab or GitHub authentication.
- For more information, see [Configuring Judge Helm](./configuring-judge-helm.md) and [our Kratos Documentation](./kratos.md)

## Conclusion

By following these setup instructions, you can deploy and configure the JUDGE stack for your environment. Ensure all components are properly configured and interconnected to enable seamless operation of the JUDGE platform. If you encounter any issues or require further assistance, please refer to the documentation or contact our support team for help.