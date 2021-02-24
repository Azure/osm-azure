# Get Started with Open Service Mesh Arc extension
Use the following scripts to publish chart, enable connected cluster, and add OSM Arc extension.

## Prerequisites
- Running Kubernetes cluster
- [Install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Add Azure CLI extensions

> Note: Get latest wheels: https://github.com/Azure/azure-arc-kubernetes-preview/tree/master/extensions

1. Install the latest [connectedk8s](https://docs.microsoft.com/en-us/cli/azure/connectedk8s?view=azure-cli-latest).
```bash
WHEEL="<location of the Azure CLI Python wheel file>"
az extension add --source $WHEEL --yes || true
```

2. Install the latest [k8s-extension](https://docs.microsoft.com/en-us/cli/azure/k8s-extension?view=azure-cli-latest).
```bash
WHEEL="<location of the Azure CLI Python wheel file>"
az extension add --source $WHEEL --yes || true
```

## Enable Arc Features
The following steps need to be run only once for a given subscription:

_Optional_: set default Azure subscription for the `az` CLI:
```bash
az account set --subscription=<your-Azure-subscription-ID>
```

```bash
az feature register \
  --namespace Microsoft.Kubernetes \
  --name previewAccess
```

```bash
az feature register \
  --namespace Microsoft.KubernetesConfiguration \
  --name sourceControlConfiguration
```

```bash
az feature register \
  --namespace Microsoft.KubernetesConfiguration \
  --name extensions
```

```bash
az provider register \
  --namespace Microsoft.ExtendedLocation
```

```bash
az feature register \
  --namespace Microsoft.ExtendedLocation \
  --name CustomLocations-ppauto
```

## Connect Cluster and Install Arc Extension

Install the Arc agent and connect the Kubernetes cluster to Azure:
> Note: `--location` must be one of `eastus`, `eastus2euap`, or `westeurope` (as of 2021-04-20).

```bash
az connectedk8s connect \
  --name=<Azure-name-of-the-Arc-connector> \
  --resource-group=<Azure-resource-group> \
  --location eastus
```

Install Open Service Mesh Arc extension:
```bash
az k8s-extension create \
  --cluster-name=<Azure-name-of-the-Arc-connector> \
  --resource-group=<Azure-resource-group> \
  --cluster-type=connectedClusters \
  --extension-type=Microsoft.openservicemesh \
  --scope=cluster \
  --release-train=staging \
  --name=osm \
  --release-namespace=arc-osm-system \
  --version=0.8.2 \
  --subscription=<Azure-subscription>
```


## Clean-up
1. Remove the Open Service Mesh Arc extension
```bash
az k8s-extension delete \
  --cluster-name=<Azure-name-of-the-Arc-connector> \
  --resource-group=<Azure-resource-group> \
  --cluster-type=connectedClusters \
  --name=osm \
  --subscription=<Azure-subscription> \
  --yes || true
```

2. Disconnect Kubernetes cluster from Azure and remove Arc agent:
```bash
az connectedk8s delete \
  --name=<Azure-name-of-the-Arc-connector> \
  --resource-group=<Azure-resource-group> || true
```


### Publish Chart to Azure Container Registry

The OSM Azure repo relies on environment variables to make it usable on your localhost. The root of the repository contains a file named `.env.example`. Copy the contents of this file into `.env`
```bash
cat .env.example > .env
```
The various environment variables are documented in the `.env.example` file itself. Modify the variables in `.env` to suite your environment.

Note: Ensure the region specified in the .env file has the latest OSM arc extension available. Supported regions listed [here](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/connect-cluster#supported-regions).


This step only needs to be run when publishing a new OSM Arc Helm chart.
```bash
./scripts/publish-chart.sh
```
