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

@test "only one osm-bootstrap pod" {
    run wait_for_condition $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-bootstrap | wc -l" "2"
    assert_success
}

@test "osm-controller pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-controller -n arc-osm-system"
    assert_success
}

@test "osm-injector pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-injector -n arc-osm-system"
    assert_success
}

@test "osm-bootstrap pod is ready" {
    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl wait --for=condition=Ready --timeout=60s pod -l app=osm-bootstrap -n arc-osm-system"
    assert_success
}

@test "mdm container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "mdm container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep mdm"
    assert_success
}

@test "msi-adapter container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "msi-adapter container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep msi-adapter"
    assert_success
}

@test "telegraf container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "telegraf container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep telegraf"
    assert_success
}

@test "prom-mdm-converter container has been deployed" {
    [ "$EXTENSION_TAG" != "1.1.1" ] && [ "$EXTENSION_TAG" = "`echo -e "$EXTENSION_TAG\n1.1.1" | sort -V | head -n1`" ] && skip "prom-mdm-converter container not deployed for $EXTENSION_TAG"

    run wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get pods -n arc-osm-system -l app=osm-metrics-agent -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | grep prom-mdm-converter"
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
