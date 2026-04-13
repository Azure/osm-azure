#!/bin/bash
#
# helpers.bash — Utility functions for BATS (Bash Automated Testing System) tests.
#
# These functions are loaded by test.bats via `load helpers` and provide common
# patterns for waiting on Kubernetes resources and asserting test outcomes.
#

# assert_success — Verify that the last command exited with status 0.
# Used after `run` commands in BATS tests to check for successful execution.
# BATS automatically sets $status and $output from the `run` command.
assert_success() {
  if [[ "$status" != 0 ]]; then
    echo "expected: 0"
    echo "actual: $status"
    echo "output: $output"
    return 1
  fi
}

# wait_for_process — Poll a command until it succeeds (exit code 0) or times out.
#
# Args:
#   $1 (wait_time)  — Maximum seconds to wait before failing
#   $2 (sleep_time) — Seconds to sleep between retries
#   $3 (cmd)        — Command string to evaluate (runs via eval)
#
# Returns 0 if the command succeeds within the timeout, 1 if it times out.
# Commonly used for `kubectl wait --for=condition=...` commands.
wait_for_process() {
  wait_time="$1"
  sleep_time="$2"
  cmd="$3"
  while [ "$wait_time" -gt 0 ]; do
    if eval "$cmd"; then
      return 0
    else
      sleep "$sleep_time"
      wait_time=$((wait_time - sleep_time))
    fi
  done
  return 1
}

# wait_for_condition — Poll a command until its output matches an expected value.
#
# Args:
#   $1 (wait_time)  — Maximum seconds to wait before failing
#   $2 (sleep_time) — Seconds to sleep between retries
#   $3 (cmd)        — Command string to evaluate (runs via eval)
#   $4 (condition)  — Expected output value to match against
#
# Returns 0 if the command output equals $condition within the timeout, 1 if it times out.
# Commonly used to check that a specific value (like a pod count or chart version) appears.
wait_for_condition() {
  wait_time="$1"
  sleep_time="$2"
  cmd="$3"
  condition="$4"
  while [ "$wait_time" -gt 0 ]; do
    result="$(eval $cmd)"
    if [[ "$condition" == "$result" ]]; then
      return 0
    else
      sleep "$sleep_time"
      wait_time=$((wait_time - sleep_time))
    fi
  done
  return 1
}
