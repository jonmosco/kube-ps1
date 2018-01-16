#!/bin/bash

# Kubernetes prompt helper for bash/zsh
# Displays current context and namespace

# Copyright 2018 Jon Mosco
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
KUBE_PS1_BINARY_DEFAULT="${KUBE_PS1_BINARY_DEFAULT:-true}"
KUBE_PS1_BINARY="${KUBE_PS1_BINARY:-kubectl}"
KUBE_PS1_SYMBOL_ENABLE="${KUBE_PS1_SYMBOL_ENABLE:-true}"
KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT:-⎈ }"
KUBE_PS1_SYMBOL_USE_IMG="${KUBE_PS1_SYMBOL_USE_IMG:-false}"
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
[[ -v KUBE_PS1_PREFIX ]] || KUBE_PS1_PREFIX="("
[[ -v KUBE_PS1_SEPARATOR ]] || KUBE_PS1_SEPARATOR="|"
[[ -v KUBE_PS1_DIVIDER ]] || KUBE_PS1_DIVIDER=":"
[[ -v KUBE_PS1_SUFFIX ]] || KUBE_PS1_SUFFIX=")"

# Default colors
KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_SYMBOL_COLOR:-blue}"
KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR:-red}"
KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR:-cyan}"

KUBE_PS1_DISABLE_PATH="${HOME}/.kube/kube-ps1/disabled"
KUBE_PS1_UNAME=$(uname)
KUBE_PS1_LAST_TIME=0

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  KUBE_PS1_SHELL="zsh"
elif [ "${BASH_VERSION-}" ]; then
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
  local SYMBOL_COLOR
  local CTX_COLOR
  local NS_COLOR

  case "${KUBE_PS1_SHELL}" in
    "zsh")
      KUBE_PS1_COLOR_OPEN="%{"
      KUBE_PS1_COLOR_CLOSE="%}"
      KUBE_PS1_RESET_COLOR="%f"

      SYMBOL_COLOR="$fg[${KUBE_PS1_SYMBOL_COLOR}]"
      CTX_COLOR="$fg[${KUBE_PS1_CTX_COLOR}]"
      NS_COLOR="$fg[${KUBE_PS1_NS_COLOR}]"
      ;;
    "bash")
      KUBE_PS1_COLOR_OPEN=$'\001'
      KUBE_PS1_COLOR_CLOSE=$'\002'
      if tput setaf 1 &> /dev/null; then
        KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}$(tput sgr0)${KUBE_PS1_COLOR_CLOSE}"
        SYMBOL_COLOR="$(tput setaf 33)"
        CTX_COLOR="$(tput setaf 1)"
        NS_COLOR="$(tput setaf 37)"
      else
        KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}$(echo -e '\033[0m')${KUBE_PS1_COLOR_CLOSE}"
        SYMBOL_COLOR="$(echo -e '\033[0;34m')"
        CTX_COLOR="$(echo -e '\033[31m')"
        NS_COLOR="$(echo -e '\033[0;36m')"
      fi
      ;;
  esac

  # Draw the colors for each shell
  _KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_COLOR_OPEN}${SYMBOL_COLOR}${KUBE_PS1_COLOR_CLOSE}"
  _KUBE_PS1_CTX_COLOR="${KUBE_PS1_COLOR_OPEN}${CTX_COLOR}${KUBE_PS1_COLOR_CLOSE}"
  _KUBE_PS1_NS_COLOR="${KUBE_PS1_COLOR_OPEN}${NS_COLOR}${KUBE_PS1_COLOR_CLOSE}"
}

# TODO: Test that the dependencies are met
_kube_ps1_binary() {
  if [[ "${KUBE_PS1_BINARY_DEFAULT}" == true ]]; then
    local KUBE_PS1_BINARY="${KUBE_PS1_BINARY_DEFAULT}"
  elif [[ "${KUBE_PS1_BINARY_DEFAULT}" == false ]] && [[ "${KUBE_PS1_BINARY}" == "oc" ]];then
    local KUBE_PS1_BINARY="oc"
  fi

  echo "${KUBE_PS1_BINARY}"
}

# TODO: Test that terminal is Unicode capable
#       If not, provide either a string like k8s, or
#       disable the label altogether
# [[ "$(locale -k LC_CTYPE | sed -n 's/^charmap="\(.*\)"/\1/p')" == *"UTF-8"* ]]
_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    local KUBE_PS1_SYMBOL_DEFAULT="☸️ "
  fi

  KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_DEFAULT}"
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
    if [[ -z "${conf}" ]]; then
      echo "Error: kubectl configuration files not found"
      return 1
    else
      if _kube_ps1_file_newer_than "${conf}" "${KUBE_PS1_LAST_TIME}"; then
        _kube_ps1_get_context_ns
        return
      fi
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

# Set symbol
_kube_ps1_symbol

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
  if [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    KUBE_PS1+="${_KUBE_PS1_SYMBOL_COLOR}${KUBE_PS1_SYMBOL}${KUBE_PS1_RESET_COLOR}"
    KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
  fi

  # Cluster Context
  KUBE_PS1+="${_KUBE_PS1_CTX_COLOR}${KUBE_PS1_CONTEXT}${KUBE_PS1_RESET_COLOR}"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    KUBE_PS1+="${_KUBE_PS1_NS_COLOR}${KUBE_PS1_NAMESPACE}${KUBE_PS1_RESET_COLOR}"
  fi

  # Suffix
  KUBE_PS1+="${KUBE_PS1_SUFFIX}"

  echo "${KUBE_PS1}"
}
