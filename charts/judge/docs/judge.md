# JUDGE - JUDGE Unified Developer & Governance Experience

## Features

### 1. Observe Build Process Telemetry

- **Asynchronous Operation:** Modern software teams operate asynchronously across highly distributed environments.
- **Observation of Build Process:** Track who triggered each build, where the build was performed, what the inputs, outputs, env, and build activities were, and how the build finished.
- **Supply Chain Tampering Prevention:** Trust but verify all types of software input artifacts to prevent supply chain tampering.

#### Dive in

1. Log in to [JUDGE](https://judge.testifysec.io/) using your GitLab or GitHub credentials.
2. Navigate to the [Repositories](https://judge.testifysec.io/repos/) page.
3. Explore how JUDGE connects with your Git provider, pulls down repositories, and displays attestations generated.
4. JUDGE helps you increase your attestation and policy adoption rate by detecting projects missing this key meta and guiding you through adoption.

#### Notes

- **Integration with Git Provider:**  JUDGE provides seamless connection with GitHub, GitLab, and possible future support for more of your favorite git providers.
- **Adoption Rate Insights:** JUDGE helps you view adoption rates of attestation generations across the enterprise.
- **Recent Git Events Review:** JUDGE highlights recent Git events that triggered attestations.

### 2. Manage Software Build Pipeline Attestations

- **Control Attestations:** Manage and control the storage, retrieval, and retention of software build pipeline attestations.
- **GraphQL Integration:** Use GraphQL for trusted telemetry integrations, exploring data sets quickly and integrating them into custom apps or connecting a Judge instance for advanced visualization.
- **Protection Against Attacks:** Resist evidence injection attacks with encrypted object storage for seamless recovery.

### 3. Act on Software Artifact Compliance

- **Visualize Provenance:** Interact with an intuitive user interface to rapidly search, locate, and inspect attestations, policies, verifications and their supporting trusted telemetry evidence.
- **Policy Creation Streamlining:** Streamline policy creation in software build pipelines, defining and digitally signing both simple and advanced in-toto policies.
- **Continuous Monitoring:** Continuously monitor software build pipelines, generating attestation reports and triggering real-time notifications of detected policy violations.

#### Policy & Verifications

##### Dive in for a Policy and Verifications Example

1. Visit our [swf](github.com/testifysec/swf).
2. Check out our [actions](https://github.com/testifysec/swf/actions), the SWF pipeline, and the verification process that makes sure our policy requirements are met before OCI submission.
3. Read the unsigned [policy.json](https://github.com/testifysec/swf/blob/main/policy.json), for an example of how you can write a policy to validate the steps in your pipeline, and other criteria
4. Head over to our [archivista-data-provider](https://github.com/testifysec/archivista-data-provider) for [gatekeeper](https://github.com/open-policy-agent/gatekeeper) which is how the swf project uses Witness to gatekeep OCI submissions through policy verifications.
5. Go to JUDGE and explore the [Verifications](https://judge.testifysec.io/verifications/) page.
6. Here you can monitor policy status and respond to incidents.

#### Search

##### Dive In

1. Be in JUDGE.
2. On the [Repositories](https://judge.testifysec.io/repos/) screen, click a chainlink icon to open the search for a commit subject.
3. This is the search results view, which includes attestation details, metadata, and certificates.
4. Enjoy the [shareability of search queries](https://judge.testifysec.io/repos/?s=94fa2ec6a230ea0476164520ed9d9a995af42dde) and the overlay feature that preserves your work.
5. Perform a search using a specific subject name, such as ["test."](https://judge.testifysec.io/repos/?s=test)

###### Notes

- **Subject-Based Search:** JUDGE can search for attestations based on subjects, providing flexibility.
- **Shareable Search Queries:** With the shareability of search queries, JUDGE facilitates higher collaboration within teams.