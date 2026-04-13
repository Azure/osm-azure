#!/usr/bin/env bats
#
# test.bats — BATS test suite for the OSM Azure Arc extension.
#
# These tests validate that the osm-arc Helm chart deployed correctly by checking:
#   - Chart version matches the expected EXTENSION_TAG
#   - All deployments in arc-osm-system are available
#   - Exactly one pod exists for each OSM component (controller, injector, bootstrap)
#   - All pods reach Ready state
#   - Metrics agent containers are deployed (mdm, msi-adapter, telegraf, prom-mdm-converter)
#   - MutatingWebhookConfiguration exists
#   - System namespaces have the openservicemesh.io/ignore label
#   - Azure Arc deployments are healthy
#
# Usage:
#   make test-e2e                            # Run all tests
#   ARC_CLUSTER=false make test-e2e          # Skip Arc-specific tests (local/KIND testing)
#   EXTENSION_TAG=1.1.1-1 make test-e2e     # Specify expected chart version
#
# Timeout configuration:
#   WAIT_TIME=120s for pod readiness, WAIT_TIME_DEPLOYMENTS=600s for deployments.
#   Metrics container tests are skipped for chart versions <= 1.1.1 (added in later versions).
#
load helpers

BATS_TESTS_DIR=test/bats/tests
WAIT_TIME=120
SLEEP_TIME=1                     # Polling interval for pod-level checks
WAIT_TIME_DEPLOYMENTS=600        # Max seconds to wait for deployments (10 minutes)
SLEEP_TIME_DEPLOYMENTS=10        # Polling interval for deployment checks
ARC_CLUSTER=${ARC_CLUSTER:-true} # Set to "false" to skip Arc-specific tests

# Verify the deployed chart version matches the expected EXTENSION_TAG.
# This catches mismatches where the wrong chart version was installed.
@test "chart version on cluster matches extension tag $EXTENSION_TAG" {
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi

    run wait_for_condition $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "helm ls -o json --namespace arc-osm-system | jq -r '.[].chart'" "osm-arc-$EXTENSION_TAG"
    assert_success
}

# Verify all deployments in arc-osm-system namespace are available.
@test "arc-osm-system deployments have succeeded" {
    run wait_for_process $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "kubectl wait --for=condition=available deployment --all --namespace arc-osm-system"
    assert_success
}

# Verify exactly one osm-controller pod exists.
# "wc -l" returns 2 because kubectl output includes the header line + 1 pod line.
@test "only one osm-controller pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-controller | wc -l" "2"
    assert_success
}

# Verify exactly one osm-injector pod exists.
@test "only one osm-injector pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-injector | wc -l" "2"
    assert_success
}

# Verify exactly one osm-bootstrap pod exists.
@test "only one osm-bootstrap pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-bootstrap | wc -l" "2"
    assert_success
}

# Verify the osm-controller pod reaches Ready state.
@test "osm-controller pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-controller -n arc-osm-system"
    assert_success
}

# Verify the osm-injector pod reaches Ready state.
@test "osm-injector pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-injector -n arc-osm-system"
    assert_success
}

# Verify the osm-bootstrap pod reaches Ready state.
@test "osm-bootstrap pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-bootstrap -n arc-osm-system"
    assert_success
}

# Verify the Geneva MDM container is deployed in the metrics agent pod.
# Skipped for chart versions <= 1.1.1 (metrics agent was added in a later release).
# The version comparison uses `sort -V` to determine if EXTENSION_TAG <= 1.1.1.
@test "mdm container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "mdm container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep mdm"
    assert_success
}

# Verify the MSI adapter container is deployed in the metrics agent pod.
@test "msi-adapter container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "msi-adapter container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep msi-adapter"
    assert_success
}

# Verify the Telegraf container is deployed in the metrics agent pod.
@test "telegraf container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "telegraf container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep telegraf"
    assert_success
}

# Verify the Prometheus-to-MDM converter container is deployed in the metrics agent pod.
@test "prom-mdm-converter container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "prom-mdm-converter container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep prom-mdm-converter"
    assert_success
}

# Verify the MutatingWebhookConfiguration for OSM sidecar injection exists.
# The webhook name "arc-osm-webhook-osm" is set by the webhookConfigNamePrefix in values.yaml.
@test "mutating webhook has been deployed" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io arc-osm-webhook-osm"
    assert_success
}

# Verify kube-system has the openservicemesh.io/ignore label.
# This label is applied by the pre-install hook job (osm-label.yml) and prevents
# Envoy sidecar injection into Kubernetes system components.
@test "openservicemesh.io/ignore is true in kube-system" { 
    test_label=$(kubectl get namespace kube-system -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}

# Verify arc-osm-system has the openservicemesh.io/ignore label.
@test "openservicemesh.io/ignore is true in arc-osm-system" { 
    test_label=$(kubectl get namespace arc-osm-system -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}

# Verify Azure Arc deployments are healthy (Arc-specific test).
@test "azure-arc deployments have succeeded" {
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi
    run wait_for_process $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "kubectl wait --for=condition=available deployment --all --namespace azure-arc"
    assert_success
}

# Verify azure-arc namespace has the openservicemesh.io/ignore label (Arc-specific test).
@test "openservicemesh.io/ignore is true in azure-arc" { 
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi
    test_label=$(kubectl get namespace azure-arc -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}
