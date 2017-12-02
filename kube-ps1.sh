#!/bin/bash

# Kubernetes prompt helper for bash/zsh
# Displays current context and namespace

# Copyright 2017 Jon Mosco
#
#  Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
KUBE_PS1_DEFAULT="${KUBE_PS1_DEFAULT:=true}"
KUBE_PS1_PREFIX="("
KUBE_PS1_DEFAULT_LABEL="${KUBE_PS1_DEFAULT_LABEL:="⎈ "}"
KUBE_PS1_DEFAULT_LABEL_IMG="${KUBE_PS1_DEFAULT_LABEL_IMG:=false}"
KUBE_PS1_SEPERATOR="|"
KUBE_PS1_PLATFORM="${KUBE_PS1_PLATFORM:="kubectl"}"
KUBE_PS1_DIVIDER=":"
KUBE_PS1_SUFFIX=")"

kube_ps1_colorize () {

  if [[ -n "${ZSH_VERSION-}" ]]; then
    blue="%F{blue}"
    reset_color="%f"
    red="%F{red}"
    cyan="%F{cyan}"
  else
    blue="\[\e[0;34m\]"
    reset_color="\[\e[0m\]"
    red="\[\e[0;31m\]"
    cyan="\[\e[0;36m\]"
  fi

}

# Test for our binary
kube_binary () {
  command -v "$1" > /dev/null 2>&1
}

kube_ps1_context_ns () {

  if [[ "${KUBE_PS1_DEFAULT}" == true ]]; then
    local KUBE_BINARY="${KUBE_PS1_PLATFORM}"
  elif [[ "${KUBE_PS1_DEFAULT}" == false ]] && [[ "${KUBE_PS1_PLATFORM}" == "kubectl" ]];then
    local KUBE_BINARY="kubectl"
  elif [[ "${KUBE_PS1_PLATFORM}" == "oc" ]]; then
    local KUBE_BINARY="oc"
  fi

  KUBE_PS1_CLUSTER="$(${KUBE_BINARY} config view --minify  --output 'jsonpath={..CurrentContext}')"
  KUBE_PS1_NAMESPACE="$(${KUBE_BINARY} config view --minify  --output 'jsonpath={..namespace}')"

}

kube_ps1_label () {

  [[ "${KUBE_PS1_DEFAULT_LABEL_IMG}" == false ]] && return

  if [[ "${KUBE_PS1_DEFAULT_LABEL_IMG}" == true ]]; then
    local KUBE_LABEL="☸️ "
  fi

  KUBE_PS1_DEFAULT_LABEL="${KUBE_LABEL}"

}

# Build our prompt
kube_ps1 () {

  # source our colors
  kube_ps1_colorize

  # source out symbol
  kube_ps1_label

  # source the context and namespace
  kube_ps1_context_ns

  KUBE_PS1="$KUBE_PS1_PREFIX${reset_color}"
  KUBE_PS1+="${blue}$KUBE_PS1_DEFAULT_LABEL"
  KUBE_PS1+="${reset_color}$KUBE_PS1_SEPERATOR"
  KUBE_PS1+="${red}$KUBE_PS1_CLUSTER${reset_color}"
  KUBE_PS1+="$KUBE_PS1_DIVIDER"
  KUBE_PS1+="${cyan}$KUBE_PS1_NAMESPACE${reset_color}"
  KUBE_PS1+="$KUBE_PS1_SUFFIX"

  echo "$KUBE_PS1"

}
