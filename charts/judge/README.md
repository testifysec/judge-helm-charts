# JUDGE Helm Chart

This Helm chart deploys JUDGE on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- You've [spoken to us and received access](https://testifysec.com/products) to JUDGE!
- Kubernetes 1.12+
- Helm 3.1.0

## Installing the Chart

### Option 1: Installing from Google Artifact Registry

To install the chart from our Google Artifact Registry with the release name `judge`:

```bash
helm install judge us-east4-docker.pkg.dev/judge-395516/judge-image-registry/judge-chart
```

### Option 2: Forking the Charts Repository

Alternatively, you can clone or fork our charts repository and install the chart locally.
This allows for full customization of our charts.
First, clone or fork the repository:

```bash
git clone https://github.com/testifysec/charts.git
cd charts
```

Then, to install the chart with the release name `judge`:

```bash
helm install judge ./judge
```

## Uninstalling the Chart

To uninstall/delete the `judge` deployment:

```sh
helm delete judge
```

Choose the option that best fits your deployment workflow: installing from our Google Artifact Registry or cloning/forking the charts repository.

## Configuring JUDGE

Configuring JUDGE with HELM can be done in a couple ways.

If you've forked the Charts repository, configure away!

If you're installing via helm cli and our Google Artifact Registry, we got you covered, too.

Head over to our [Configuring JUDGE](./docs/configuring-judge-helm.md) doc to learn more.