# Testing

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