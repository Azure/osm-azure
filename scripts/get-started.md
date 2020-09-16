## Get Started
Use the following scripts to publish chart, enable connected cluster, and add OSM Arc extension.

### Set env vars

```sh
# set subscription and identity env
export TENANTID=
export SUBSCRIPTION=
export CLIENTID=
export CLIENTSECRET=
# set cluster env
export RESOURCEGROUP=
export CLUSTERNAME=
# set chart release env
# NOTE: osmstaging.azurecr.io/helm/osm is the staging ACR
# Create an ICM Ticket with ACR team to enable anonymous access so that artifacts can be pulled from ACR with public access 
# e.g. https://portal.microsofticm.com/imp/v3/incidents/details/160520779/home
export CHARTPATH=
export REGISTRY=osmstaging.azurecr.io
export REPO=osmstaging.azurecr.io/helm/osm
export RELEASE=
```

### Publish Chart to Azure Container Registry

```sh
./scripts/publish-chart.sh
```

### Enable Arc Features

```sh
./scripts/enable-arc-feature.sh
```

### Add Arc Extension to Cluster

```sh
./scripts/add-extension.sh
```