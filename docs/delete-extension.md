# Delete OSM Arc extension

## Instructions
1. [Set environment variables in .env file](./get-started#SetEnvVars)
1. Run `./scripts/delete-extension.sh`

## Time for deletion
The current SLA for [Arc extension deletion](https://github.com/Azure/azure-arc-kubernetes-preview/blob/3b69da3d4b695229d044811869e48afcbd78ded9/docs/k8s-extensions.md#delete-extension-instance) is 10 min.

## Resource management
See the [OSM uninstallation guide](https://github.com/openservicemesh/osm/blob/main/docs/uninstallation_guide.md) for more details on which resources are cleaned up and which resources remain after cleanup.

## Arc specific resources 

### Removed during extension deletion
1. Resources deployed by the extension in the `arc-osm-system` Kubernetes namespace
1. `osm` Helm chart in `arc-osm-system` namespace

### Remaining after extension deletion
1. `azure-arc` Helm chart in `default` namespace
1. `azure-arc` Kubernetes namespace and its resources
1. `arc-osm-system` Kubernetes namespace

