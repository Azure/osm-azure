## Get Started
Use the following scripts to publish chart, enable connected cluster, and add OSM Arc extension.

## Prerequisites
- Running Kubernetes cluster
- Azure CLI

### Set env vars
The OSM Azure repo relies on environment variables to make it usable on your localhost. The root of the repository contains a file named `.env.example`. Copy the contents of this file into `.env`
```bash
cat .env.example > .env
```
The various environment variables are documented in the `.env.example` file itself. Modify the variables in `.env` to suite your environment.

Note: Ensure the region specified in the .env file has the latest OSM arc extension available. Supported regions listed [here](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/connect-cluster#supported-regions).


### Enable Arc Features
This step needs to be run only once for every new subscription.
```sh
./scripts/enable-arc-feature.sh
```

### Add Arc Extension to Cluster
This step needs to be run for each Kubernetes cluster that needs the Arc OSM extension. It will add the connectedk8s extension to the Azure CLI, enable arc on the Kubernetes cluster (installs arc agents and components), and install the osm arc extension on the Kubernetes cluster.
```sh
./scripts/add-extension.sh
```

### Remove Arc Extension from Cluster
This step needs to be run for each cluster when you want to remove the OSM Arc extension. Note that this script does not remove Arc connectivity.

This script also does not delete the `arc-osm-system` and `azure-arc` namespaces.
```sh
./scripts/delete-extension.sh
```

### Publish Chart to Azure Container Registry
This step only needs to be run when publishing a new OSM Arc Helm chart.
```sh
./scripts/publish-chart.sh
```
