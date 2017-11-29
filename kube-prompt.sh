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
KUBE_PROMPT_DEFAULT="${KUBE_PROMPT_DEFAULT:=true}"
KUBE_PROMPT_PREFIX="("
KUBE_PROMPT_DEFAULT_LABEL="${KUBE_PROMPT_DEFAULT_LABEL:="⎈ "}"
KUBE_PROMPT_DEFAULT_LABEL_IMG="${KUBE_PROMPT_DEFAULT_LABEL_IMG:=false}"
KUBE_PROMPT_SEPERATOR="|"
KUBE_PROMPT_PLATFORM="${KUBE_PROMPT_PLATFORM:="kubectl"}"
KUBE_PROMPT_DIVIDER=":"
KUBE_PROMPT_SUFFIX=")"

kube_prompt_colorize () {

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

kube_prompt_context_ns () {

  if [[ "${KUBE_PROMPT_DEFAULT}" == true ]]; then
    local KUBE_BINARY="${KUBE_PROMPT_PLATFORM}"
  elif [[ "${KUBE_PROMPT_DEFAULT}" == false ]] && [[ "${KUBE_PROMPT_PLATFORM}" == "kubectl" ]];then
    local KUBE_BINARY="kubectl"
  elif [[ "${KUBE_PROMPT_PLATFORM}" == "oc" ]]; then
    local KUBE_BINARY="oc"
  fi

  KUBE_PROMPT_CLUSTER="$(${KUBE_BINARY} config view --minify  --output 'jsonpath={..CurrentContext}')"
  KUBE_PROMPT_NAMESPACE="$(${KUBE_BINARY} config view --minify  --output 'jsonpath={..namespace}')"

}

kube_prompt_label () {

  [[ "${KUBE_PROMPT_DEFAULT_LABEL_IMG}" == false ]] && return

  if [[ "${KUBE_PROMPT_DEFAULT_LABEL_IMG}" == true ]]; then
    local KUBE_LABEL="☸️ "
  fi

  KUBE_PROMPT_DEFAULT_LABEL="${KUBE_LABEL}"

}

# Build our prompt
kube_prompt () {

  # source our colors
  kube_prompt_colorize

  # source out symbol
  kube_prompt_label

  # source the context and namespace
  kube_prompt_context_ns

  KUBE_PROMPT="$KUBE_PROMPT_PREFIX${reset_color}"
  KUBE_PROMPT+="${blue}$KUBE_PROMPT_DEFAULT_LABEL"
  KUBE_PROMPT+="${reset_color}$KUBE_PROMPT_SEPERATOR"
  KUBE_PROMPT+="${red}$KUBE_PROMPT_CLUSTER${reset_color}"
  KUBE_PROMPT+="$KUBE_PROMPT_DIVIDER"
  KUBE_PROMPT+="${cyan}$KUBE_PROMPT_NAMESPACE${reset_color}"
  KUBE_PROMPT+="$KUBE_PROMPT_SUFFIX"

  echo "$KUBE_PROMPT"

}
