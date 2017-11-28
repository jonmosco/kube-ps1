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

kube_prompt_platform () {

  if [[ -f $(which oc) && -x $(which oc) ]]; then
    prompt_binary="oc"
    prompt_label="ocp"
  else
    prompt_binary="kubectl"
    prompt_label="k8s"
  fi
}

kube_prompt () {

  # source our colors
  kube_prompt_colorize
  # source prompt platform
  kube_prompt_platform

  K8S_PROMPT_PREFIX="("
  K8S_PROMPT_LABEL="${prompt_label}"
  K8S_PROMPT_SEPERATOR="|"
  K8S_PROMPT_CLUSTER="$(${prompt_binary} config view --minify  --output 'jsonpath={..CurrentContext}')"
  K8S_PROMPT_DIVIDER=":"
  K8S_PROMPT_NAMESPACE="$(${prompt_binary} config view --minify  --output 'jsonpath={..namespace}')"
  K8S_PROMPT_SUFFIX=")"

  K8S_PROMPT="$K8S_PROMPT_PREFIX${reset_color}"
  K8S_PROMPT+="${blue}$K8S_PROMPT_LABEL"
  K8S_PROMPT+="${reset_color}$K8S_PROMPT_SEPERATOR"
  K8S_PROMPT+="${red}$K8S_PROMPT_CLUSTER${reset_color}"
  K8S_PROMPT+="$K8S_PROMPT_DIVIDER"
  K8S_PROMPT+="${cyan}$K8S_PROMPT_NAMESPACE${reset_color}"
  K8S_PROMPT+="$K8S_PROMPT_SUFFIX"

  echo "$K8S_PROMPT"

}
