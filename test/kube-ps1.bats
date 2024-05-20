#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/../kube-ps1.sh" >/dev/null 2>/dev/null

load common

@test "kubeon with no arguments" {
  run bash -c 'kubeon; echo "KUBE_PS1_ENABLED=$KUBE_PS1_ENABLED"'
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "kubeon with --help" {
  run kubeon --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Toggle kube-ps1 prompt on"* ]]
}

@test "kubeon with -g" {
  run kubeon -g
  [ "$status" -eq 0 ]
  [ ! -f "$_KUBE_PS1_DISABLE_PATH" ]
}

@test "kubeon with invalid flag" {
  run kubeon --invalid
  [ "$status" -eq 0 ]
  [[ "$output" == *"error: unrecognized flag --invalid"* ]]
}

@test "kubeoff with no arguments" {
  run bash -c 'kubeooff; echo "$KUBE_PS1_ENABLED"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"off"* ]]
}

@test "kubeoff with --help" {
  run kubeoff --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Toggle kube-ps1 prompt off"* ]]
}

@test "kubeoff with -g" {
  run kubeoff -g
  [ "$status" -eq 0 ]
  [ -f "$_KUBE_PS1_DISABLE_PATH" ]
}

@test "kubeoff with invalid flag" {
  run kubeoff --invalid
  [ "$status" -eq 0 ]
  [[ "$output" == *"error: unrecognized flag --invalid"* ]]
}

@test "kube_ps1_shell_type returns correct shell type" {
  # Simulate bash
  export BASH_VERSION="5.0.0"
  run _kube_ps1_shell_type
  [ "$status" -eq 0 ]
  [ "$output" = "bash" ]

  # Simulate zsh
  unset BASH_VERSION
  export ZSH_VERSION="5.0.0"
  run _kube_ps1_shell_type
  [ "$status" -eq 0 ]
  [ "$output" = "zsh" ]
}

@test "_kube_ps1_binary_check returns true for existing command" {
  run _kube_ps1_binary_check ls
  [ "$status" -eq 0 ]
}

@test "_kube_ps1_binary_check returns false for non-existing command" {
  run _kube_ps1_binary_check nonexistingcommand
  [ "$status" -ne 0 ]
}

@test "_kube_ps1_symbol returns the default symbol" {
  run _kube_ps1_symbol
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"⎈"* ]]
}

@test "export KUBE_PS1_SYMBOL=k8s returns 󱃾" {
  export KUBE_PS1_SYMBOL_CUSTOM=k8s
  run _kube_ps1_symbol
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"󱃾"* ]]
}

@test "export KUBE_PS1_SYMBOL=img returns ☸️" {
  export KUBE_PS1_SYMBOL_CUSTOM=img
  run _kube_ps1_symbol
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"☸️"* ]]
}

@test "export KUBE_PS1_SYMBOL=oc returns " {
  export KUBE_PS1_SYMBOL_CUSTOM=oc
  run _kube_ps1_symbol
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *""* ]]
}

@test "kube_ps1 returns correct prompt when enabled" {
  export KUBE_PS1_ENABLED="on"
  export KUBE_PS1_CONTEXT="minikube"
  export KUBE_PS1_NAMESPACE="default"
  run kube_ps1
  [ "$status" -eq 0 ]
  [[ "$output" == *"minikube"* ]]
  [[ "$output" == *"default"* ]]
}

@test "kube_ps1 returns empty prompt when disabled" {
  export KUBE_PS1_ENABLED="off"
  run kube_ps1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

