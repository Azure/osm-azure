# Testing

## Azure Pipelines authentication

The following pipelines use the Azure Resource Manager service connection
`WIF - staging - upstream-ado-agent-identity`, rather than the managed identity
assigned to the agent pool:

| Pipeline | Azure operations |
| --- | --- |
| `.pipelines/pr-job/e2e-job.yaml` | Publish and register the chart, create an AKS/Arc test cluster, and clean up |
| `.pipelines/upgrade-job/upgrade-e2e-job.yaml` | Run the chart upgrade tests using the same PR job template |
| `.pipelines/aks-addon-nightly/e2e-aks-addon.yaml` | Create an AKS cluster, enable the OSM addon, and clean up |
| `.pipelines/test-prod-job/osm-arc-prod-test-job.yaml` | Test a production extension version on a staging test cluster |
| `.pipelines/conformance-test-job/conf-test-plugin-job.yaml` | Push the conformance plugin image to ACR |

This follows the WIF pattern in
[ado-build-definitions](https://dev.azure.com/AzureContainerUpstream/Kubernetes/_git/ado-build-definitions?path=/pipelines/templates/az-login-wif.yml).
The service connection must use **workload identity federation**, be authorized
for each pipeline, and have the registry, AKS/resource group, and Arc permissions
previously granted to the pool identity. The agents must support `AzureCLI@3`.
The production-extension test also uses the staging connection because its
resources are created on the staging pool.

The shared `az-login-wif.yaml` template obtains a federated token through the
service connection and establishes a separate Azure CLI session for subsequent
Bash steps, including the Arc scripts. It selects the service connection's
subscription and isolates the CLI configuration in a job-specific directory
under `Agent.TempDirectory`. The token file is private and removed after login;
the agent cleans up the temporary CLI configuration at the end of the job.
Cleanup tasks use their own `AzureCLI@3` login with `condition: always()` so they
do not depend on an earlier login surviving a failed or long-running test.

The `aks-setup.yaml`, `aks-cleanup.yaml`, `publish-helm-chart.yaml`,
`push-conf-image-acr.yaml`, `register-extension.yaml`, and `acr-cleanup.yaml` templates accept a
`serviceConnection` parameter with the staging connection as their default.
When reusing them with another connection, pass it consistently to setup,
publish, registration, and cleanup templates. AKS `--enable-managed-identity` remains
unchanged: it configures the cluster identity, not agent authentication.

## Prerequisites
To run tests locally, you can either run `make install-prerequisites` or manually set up the resources below.
> Note: if you would like to bootstrap a [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) cluster for local testing, run this make target with `TEST_KIND=true`


1. A kubernetes cluster
1. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
1. [bats](https://github.com/bats-core/bats-core#installing-bats-from-source)
1. [Helm 3](https://helm.sh/docs/intro/install/)

## Running tests
To run end to end tests locally, carry out the following steps from root:

1. To bootstrap resources required for testing:
    ```
    make e2e-bootstrap
    ```

1. To deploy the chart with local changes: 
    ```
    make e2e-helm-deploy
    ```
1. To run all end to end tests: 
    ```
    make test-e2e
    ```
    If you are testing on a cluster that is not Arc enabled, Arc-specific tests will fail. Run this target with `ARC_CLUSTER=false` to skip these tests. 

1. To clean up resources from cluster: 
    ```
    make e2e-cleanup
    ```
    If using a kind cluster, run with `TEST_KIND=true`