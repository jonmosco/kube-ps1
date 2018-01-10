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

# Debug
[[ -n $DEBUG ]] && set -x

# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
KUBE_PS1_BINARY_DEFAULT="${KUBE_PS1_DEFAULT:-true}"
KUBE_PS1_BINARY="${KUBE_PS1_BINARY:-kubectl}"
KUBE_PS1_DISABLE_PATH="${HOME}/.kube/kube-ps1/disabled"
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
KUBE_PS1_UNAME=$(uname)
KUBE_PS1_LABEL_ENABLE="${KUBE_PS1_LABEL_ENABLE:-true}"
# If needed, the unicode sequence for this symbol is \u2388
KUBE_PS1_LABEL_DEFAULT="${KUBE_PS1_LABEL_DEFAULT:-⎈ }"
KUBE_PS1_LABEL_USE_IMG="${KUBE_PS1_LABEL_USE_IMG:-false}"
KUBE_PS1_LAST_TIME=0
KUBE_PS1_PREFIX="${KUBE_PS1_PREFIX:-(}"
KUBE_PS1_SEPARATOR="${KUBE_PS1_SEPARATOR:-|}"
KUBE_PS1_DIVIDER="${KUBE_PS1_DIVIDER:-:}"
KUBE_PS1_SUFFIX="${KUBE_PS1_SUFFIX:-)}"

if [ "${ZSH_VERSION}" ]; then
  KUBE_PS1_SHELL="zsh"
elif [ "${BASH_VERSION}" ]; then
  KUBE_PS1_SHELL="bash"
fi

_kube_ps1_shell_settings() {
  case "${KUBE_PS1_SHELL}" in
    "zsh")
      setopt PROMPT_SUBST
      autoload -U add-zsh-hook
      add-zsh-hook precmd _kube_ps1_load
      zmodload zsh/stat
      ;;
    "bash")
      PROMPT_COMMAND="${PROMPT_COMMAND:-:};_kube_ps1_load"
      ;;
  esac
}

_kube_ps1_colors() {
  case "${KUBE_PS1_SHELL}" in
    "zsh")
      KUBE_PS1_RESET_COLOR="%f"
      KUBE_PS1_LABEL_COLOR="${KUBE_PS1_LABEL_COLOR:-%F{blue}}"
      KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR:-%F{red}}"
      KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR:-%F{cyan}}"
      ;;
    "bash")
      KUBE_PS1_COLOR_OPEN=$'\001'
      KUBE_PS1_COLOR_CLOSE=$'\002'
      if tput setaf 1 &> /dev/null; then
        KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}$(tput sgr0)${KUBE_PS1_COLOR_CLOSE}"
        KUBE_PS1_LABEL_COLOR="${KUBE_PS1_LABEL_COLOR:-${KUBE_PS1_COLOR_OPEN}$(tput setaf 33)${KUBE_PS1_COLOR_CLOSE}}"
        KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR:-${KUBE_PS1_COLOR_OPEN}$(tput setaf 1)${KUBE_PS1_COLOR_CLOSE}}"
        KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR:-${KUBE_PS1_COLOR_OPEN}$(tput setaf 37)${KUBE_PS1_COLOR_CLOSE}}"
      else
        KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}$(echo -e '\033[0m')${KUBE_PS1_COLOR_CLOSE}"
        KUBE_PS1_LABEL_COLOR="${KUBE_PS1_LABEL_COLOR:-${KUBE_PS1_COLOR_OPEN}$(echo -e '\033[0;34m')${KUBE_PS1_COLOR_CLOSE}}"
        KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR:-${KUBE_PS1_COLOR_OPEN}$(echo -e '\033[31m')${KUBE_PS1_COLOR_CLOSE}}"
        KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR:-${KUBE_PS1_COLOR_OPEN}$(echo -e '\033[0;36m')${KUBE_PS1_COLOR_CLOSE}}"
      fi
      ;;
  esac
}

_kube_ps1_binary() {
  if [[ "${KUBE_PS1_BINARY_DEFAULT}" == true ]]; then
    local KUBE_PS1_BINARY="${KUBE_PS1_BINARY_DEFAULT}"
  elif [[ "${KUBE_PS1_BINARY_DEFAULT}" == false ]] && [[ "${KUBE_PS1_BINARY}" == "oc" ]];then
    local KUBE_PS1_BINARY="oc"
  fi

  KUBE_PS1_BINARY="${KUBE_PS1_BINARY}"
}

kube_ps1_label() {
  [[ "${KUBE_PS1_LABEL_ENABLE}" == false ]] && return

  if [[ "${KUBE_PS1_LABEL_USE_IMG}" == true ]]; then
    local KUBE_PS1_LABEL_DEFAULT="☸️ "
  fi

  KUBE_PS1_LABEL="${KUBE_PS1_LABEL_DEFAULT}"
}

_kube_ps1_split() {
  type setopt >/dev/null 2>&1 && setopt SH_WORD_SPLIT
  local IFS=$1
  echo $2
}

_kube_ps1_file_newer_than() {
  local mtime
  local file=$1
  local check_time=$2

  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    mtime=$(stat +mtime "${file}")
  elif [ x"$KUBE_PS1_UNAME" = x"Linux" ]; then
    mtime=$(stat -c %Y "${file}")
  else
    mtime=$(stat -f %m "$file")
  fi

  [ "${mtime}" -gt "${check_time}" ]
}

_kube_ps1_load() {
  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  : "${KUBECONFIG:=$HOME/.kube/config}"

  for conf in $(_kube_ps1_split : "${KUBECONFIG}"); do
    if _kube_ps1_file_newer_than "${conf}" "${KUBE_PS1_LAST_TIME}"; then
      # TODO: Test here for these values being set
      _kube_ps1_get_context_ns
      return
    fi
  done
}

# TODO: Break this function apart:
#       one for context and one for namespace
_kube_ps1_get_context_ns() {
  # Set the command time
  KUBE_PS1_LAST_TIME=$(date +%s)

  KUBE_PS1_CONTEXT="$(${KUBE_PS1_BINARY} config current-context)"
  if [[ -z "${KUBE_PS1_CONTEXT}" ]]; then
    echo "kubectl context is not set"
    return 1
  fi

  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1_NAMESPACE="$(${KUBE_PS1_BINARY} config view --minify --output 'jsonpath={..namespace}')"
    # Set namespace to default if it is not defined
    KUBE_PS1_NAMESPACE="${KUBE_PS1_NAMESPACE:-default}"
  fi
}

# Set shell options
_kube_ps1_shell_settings

# Set colors
_kube_ps1_colors

# source our symbol
kube_ps1_label

kubeon() {
  rm -rf "${KUBE_PS1_DISABLE_PATH}"
}

kubeoff() {
  mkdir -p "$(dirname $KUBE_PS1_DISABLE_PATH)"
  touch "${KUBE_PS1_DISABLE_PATH}"
}

# Build our prompt
kube_ps1() {
  [ -f "${KUBE_PS1_DISABLE_PATH}" ] && return

  # Prefix
  KUBE_PS1="${KUBE_PS1_PREFIX}"
  # Label
  if [[ "${KUBE_PS1_LABEL_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_LABEL_COLOR}${KUBE_PS1_LABEL}${KUBE_PS1_RESET_COLOR}"
    KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
  fi
  # Cluster Context
  KUBE_PS1+="${KUBE_PS1_CTX_COLOR}${KUBE_PS1_CONTEXT}${KUBE_PS1_RESET_COLOR}"
  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    KUBE_PS1+="${KUBE_PS1_NS_COLOR}$KUBE_PS1_NAMESPACE${KUBE_PS1_RESET_COLOR}"
  fi
  # Suffix
  KUBE_PS1+="${KUBE_PS1_SUFFIX}"

  echo "${KUBE_PS1}"
}
