#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../kube-ps1.sh" >/dev/null 2>/dev/null
  export _KUBE_PS1_DISABLE_PATH="/tmp/kube_ps1_disable"
  export KUBECONFIG="/tmp/kubeconfig"
  mkdir -p /tmp/kube-ps1
  touch /tmp/kubeconfig
}

teardown() {
  unset _KUBE_PS1_DISABLE_PATH
  unset KUBECONFIG
  unset KUBE_PS1_ENABLED
  unset KUBE_PS1_CONTEXT
  unset KUBE_PS1_NAMESPACE
  unset KUBE_PS1_SYBBOL_COLOR
  unset KUBE_PS1_SYMBOL_CUSTOM
  rm -rf /tmp/kube-ps1
  rm -f /tmp/kubeconfig
}
