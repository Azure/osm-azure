#!/usr/bin/env bats
load helpers

BATS_TESTS_DIR=test/bats/tests
WAIT_TIME=120
SLEEP_TIME=1

@test "osm pod has been deployed and is running." {
    wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get deployment/osm-controller"

    run kubectl get deployment/osm-controller
    assert_success
}

@test "configmap has been deployed" {
    run kubectl get configmap/osm-config
    assert_success
}

@test "mutating webhook has been deployed" {
    wait_for_process $WAIT_TIME $SLEEP_TIME "kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io osm-webhook-osm"
    
    run kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io osm-webhook-osm
    assert_success
}
