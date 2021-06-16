#!/usr/bin/env bats
load helpers

BATS_TESTS_DIR=test/bats/tests
WAIT_TIME=120
SLEEP_TIME=1
WAIT_TIME_DEPLOYMENTS=600
SLEEP_TIME_DEPLOYMENTS=10
ARC_CLUSTER=${ARC_CLUSTER:-true}

@test "chart version on cluster matches extension tag $EXTENSION_TAG" {
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi

    run wait_for_condition $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "helm ls -o json --namespace arc-osm-system | jq -r '.[].chart'" "osm-arc-$EXTENSION_TAG"
    assert_success
}

@test "arc-osm-system deployments have succeeded" {
    run wait_for_process $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "kubectl wait --for=condition=available deployment --all --namespace arc-osm-system"
    assert_success
}

@test "only one osm-controller pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-controller | wc -l" "2"
    assert_success
}

@test "only one osm-injector pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-injector | wc -l" "2"
    assert_success
}

@test "osm pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-controller -n arc-osm-system"
    assert_success
}

@test "mutating webhook has been deployed" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io arc-osm-webhook-osm"
    assert_success
}

@test "openservicemesh.io/ignore is true in kube-system" { 
    test_label=$(kubectl get namespace kube-system -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}

@test "openservicemesh.io/ignore is true in arc-osm-system" { 
    test_label=$(kubectl get namespace arc-osm-system -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}

@test "azure-arc deployments have succeeded" {
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi
    run wait_for_process $WAIT_TIME_DEPLOYMENTS $SLEEP_TIME_DEPLOYMENTS "kubectl wait --for=condition=available deployment --all --namespace azure-arc"
    assert_success
}

@test "openservicemesh.io/ignore is true in azure-arc" { 
    if [ $ARC_CLUSTER == false ]; then
        skip "arc cluster-specific test"
    fi
    test_label=$(kubectl get namespace azure-arc -o jsonpath="{.metadata.labels.openservicemesh\.io\/ignore}")
    [[ $test_label == "true" ]]
}
