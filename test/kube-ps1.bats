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
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 1 ]
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

@test "hide-if-no-context hides a namespace-only prompt without a config" {
  mock_kube_client() {
    return 0
  }

  export KUBE_PS1_BINARY=mock_kube_client
  export KUBE_PS1_CONTEXT_ENABLE=false
  export KUBE_PS1_HIDE_IF_NOCONTEXT=true
  export HOME=/tmp/kube-ps1/no-home
  unset KUBECONFIG
  _KUBE_PS1_KUBECONFIG_CACHE=
  _KUBE_PS1_LAST_TIME=0

  _kube_ps1_prompt_update
  run kube_ps1

  [ "$status" -eq 0 ]
  [ "${_KUBE_PS1_HAS_CONTEXT}" = false ]
  [ -z "$output" ]
}

@test "hide-if-no-context displays a namespace-only prompt with a context" {
  mock_kube_client() {
    if [[ "$*" == "config current-context" ]]; then
      printf 'active-context'
    elif [[ "$*" == *"config view"* ]]; then
      printf 'active-namespace'
    fi
  }

  export KUBE_PS1_BINARY=mock_kube_client
  export KUBE_PS1_CONTEXT_ENABLE=false
  export KUBE_PS1_HIDE_IF_NOCONTEXT=true
  export KUBE_PS1_SYMBOL_ENABLE=false
  export KUBE_PS1_NS_COLOR=

  _kube_ps1_get_context_ns
  run kube_ps1

  [ "$status" -eq 0 ]
  [ "${_KUBE_PS1_HAS_CONTEXT}" = true ]
  [[ "$output" == *"active-namespace"* ]]
}

@test "prompt update refreshes after the configured binary becomes available again" {
  export HOME="${BATS_TEST_TMPDIR}"
  unset KUBECONFIG
  export KUBE_PS1_BINARY=mock_recovering_client
  export KUBE_PS1_ENABLED=on
  export KUBE_PS1_CONTEXT_ENABLE=true
  export KUBE_PS1_NS_ENABLE=true
  export KUBE_PS1_HIDE_IF_NOCONTEXT=true

  mock_recovering_client() {
    case "$*" in
      'config current-context') printf 'active-context' ;;
      *) printf 'active-namespace' ;;
    esac
  }

  _kube_ps1_prompt_update
  [ "${KUBE_PS1_CONTEXT}" = active-context ]
  [ "${_KUBE_PS1_LAST_TIME}" -gt 0 ]

  unset -f mock_recovering_client
  _kube_ps1_prompt_update
  [ "${KUBE_PS1_CONTEXT}" = BINARY-N/A ]
  [ "${_KUBE_PS1_LAST_TIME}" = 0 ]
  run kube_ps1
  [[ "$output" == *BINARY-N/A* ]]

  mock_recovering_client() {
    case "$*" in
      'config current-context') printf 'restored-context' ;;
      *) printf 'restored-namespace' ;;
    esac
  }

  _kube_ps1_prompt_update
  [ "${KUBE_PS1_CONTEXT}" = restored-context ]
  [ "${KUBE_PS1_NAMESPACE}" = restored-namespace ]
  [ "${_KUBE_PS1_HAS_CONTEXT}" = true ]
  [ "${_KUBE_PS1_LAST_TIME}" -gt 0 ]
}

@test "context refresh records the current timestamp" {
  mock_clock_client() { return 0; }
  export KUBE_PS1_BINARY=mock_clock_client
  local before after
  before=$(date +%s)
  _kube_ps1_get_context_ns
  after=$(date +%s)
  [ "${_KUBE_PS1_LAST_TIME}" -ge "$before" ]
  [ "${_KUBE_PS1_LAST_TIME}" -le "$after" ]
}

@test "context customization does not affect context availability" {
  mock_kube_client() {
    if [[ "$*" == "config current-context" ]]; then
      printf 'active-context'
    elif [[ "$*" == *"config view"* ]]; then
      printf 'active-namespace'
    fi
  }
  format_context_as_na() {
    printf 'N/A'
  }

  export KUBE_PS1_BINARY=mock_kube_client
  export KUBE_PS1_CONTEXT_ENABLE=true
  export KUBE_PS1_HIDE_IF_NOCONTEXT=true
  export KUBE_PS1_CLUSTER_FUNCTION=format_context_as_na
  export KUBE_PS1_SYMBOL_ENABLE=false
  export KUBE_PS1_CTX_COLOR=
  export KUBE_PS1_NS_COLOR=

  _kube_ps1_get_context_ns
  run kube_ps1

  [ "$status" -eq 0 ]
  [ "${_KUBE_PS1_HAS_CONTEXT}" = true ]
  [[ "$output" == *"active-namespace"* ]]
}

