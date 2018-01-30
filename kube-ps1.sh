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
KUBE_PS1_SYMBOL_DEFAULT=${KUBE_PS1_SYMBOL_DEFAULT:-$'\u2388 '}
KUBE_PS1_SYMBOL_USE_IMG="${KUBE_PS1_SYMBOL_USE_IMG:-false}"
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
KUBE_PS1_PREFIX="${KUBE_PS1_PREFIX-(}"
KUBE_PS1_SEPARATOR="${KUBE_PS1_SEPARATOR-|}"
KUBE_PS1_DIVIDER="${KUBE_PS1_DIVIDER-:}"
KUBE_PS1_SUFFIX="${KUBE_PS1_SUFFIX-)}"

# Default colors
KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_SYMBOL_COLOR:-blue}"
KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR:-red}"
KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR:-cyan}"
KUBE_PS1_BG_COLOR="${KUBE_PS1_BG_COLOR}"

KUBE_PS1_KUBECONFIG_CACHE="${KUBECONFIG}"
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
      add-zsh-hook precmd _kube_ps1_update_cache
      zmodload zsh/stat
      ;;
    "bash")
      PROMPT_COMMAND="_kube_ps1_update_cache;${PROMPT_COMMAND:-:}"
      ;;
  esac
}

_kube_ps1_colors() {
  local SYMBOL_COLOR
  local BG_COLOR
  local CTX_COLOR
  local NS_COLOR
  local KUBE_PS1_BG_CLOSE
  local KUBE_PS1_COLOR_OPEN
  local KUBE_PS1_COLOR_CLOSE

  case "${KUBE_PS1_SHELL}" in
    "zsh")
      KUBE_PS1_BG_CLOSE="%k"
      KUBE_PS1_COLOR_OPEN="%{"
      KUBE_PS1_COLOR_CLOSE="%}"
      KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}%f${KUBE_PS1_COLOR_CLOSE}"

      BG_COLOR="%K{${KUBE_PS1_BG_COLOR}}"
      SYMBOL_COLOR="%F{${KUBE_PS1_SYMBOL_COLOR}}"
      CTX_COLOR="%F{${KUBE_PS1_CTX_COLOR}}"
      NS_COLOR="%F{${KUBE_PS1_NS_COLOR}}"
      ;;
    "bash")
      KUBE_PS1_COLOR_OPEN=$'\001'
      KUBE_PS1_COLOR_CLOSE=$'\002'
      if tput setaf 1 &> /dev/null; then
        KUBE_PS1_RESET_COLOR="${KUBE_PS1_COLOR_OPEN}$(tput sgr0)${KUBE_PS1_COLOR_CLOSE}"
        BG_COLOR="$(tput setab 7)"
        KUBE_PS1_BG_CLOSE="${KUBE_PS1_COLOR_OPEN}$(tput sgr0)${KUBE_PS1_COLOR_CLOSE}"
        SYMBOL_COLOR="$(tput setaf 33)"
        CTX_COLOR="$(tput setaf 1)"
        NS_COLOR="$(tput setaf 37)"
      else
        KUBE_PS1_RESET_COLOR=${KUBE_PS1_COLOR_OPEN}$'\033[0m'${KUBE_PS1_COLOR_CLOSE}
        SYMBOL_COLOR=$'\033[0;34m'
        CTX_COLOR=$'\033[31m'
        NS_COLOR=$'\033[0;36m'
      fi
      ;;
  esac

  # Draw the colors for each shell
  _KUBE_PS1_BG_COLOR="${KUBE_PS1_COLOR_OPEN}${BG_COLOR}${KUBE_PS1_COLOR_CLOSE}"
  _KUBE_PS1_BG_COLOR_CLOSE="${KUBE_PS1_COLOR_OPEN}${KUBE_PS1_BG_CLOSE}${KUBE_PS1_COLOR_CLOSE}"
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

_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  # TODO: Test if LANG is not set
  if [[ $LANG =~ UTF-?8$ ]]; then
    local _KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT}"
    local _KUBE_PS1_SYMBOL_IMG=$'\u2638 '
  else
    local _KUBE_PS1_SYMBOL_DEFAULT="k8s"
  fi

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_IMG}"
  else
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_DEFAULT}"
  fi
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

_kube_ps1_update_cache() {
  [[ -n "${KUBE_PS1_TOGGLE}" ]] && return
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && return

  local conf
  if [[ "${KUBECONFIG}" != "${KUBE_PS1_KUBECONFIG_CACHE}" ]]; then
    KUBE_PS1_KUBECONFIG_CACHE=${KUBECONFIG}
    _kube_ps1_get_context_ns
    return
  fi

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  for conf in $(_kube_ps1_split : "${KUBECONFIG:-$HOME/.kube/config}"); do
    [[ -r "${conf}" ]] || continue
    if _kube_ps1_file_newer_than "${conf}" "${KUBE_PS1_LAST_TIME}"; then
      _kube_ps1_get_context_ns
      return
    fi
  done
}

# TODO: Break this function apart:
#       one for context and one for namespace
_kube_ps1_get_context_ns() {
  # Set the command time
  # TODO: Use a builtin instead of date
  # KUBE_PS1_LAST_TIME=$(printf %t)
  KUBE_PS1_LAST_TIME=$(date +%s)

  KUBE_PS1_CONTEXT="$(${KUBE_PS1_BINARY} config current-context 2>/dev/null)"
  if [[ -z "${KUBE_PS1_CONTEXT}" ]]; then
    KUBE_PS1_CONTEXT="N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  elif [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1_NAMESPACE="$(${KUBE_PS1_BINARY} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
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

_kube_toggle_on_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt on

Usage: kubeon [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global  turn on kube-ps1 status globally
  -h --help    print this message
EOF
}

_kube_toggle_off_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt off

Usage: kubeoff [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global turn off kube-ps1 status globally
  -h --help   print this message
EOF
}

kubeon() {
  if [[ "$#" -eq 0 ]]; then
    unset KUBE_PS1_TOGGLE
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kube_toggle_on_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "${1}" != '-g' && "${1}" != '--global' ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
   _kube_toggle_on_usage
  else
    _kube_toggle_on_usage
    return
  fi
}

kubeoff() {
  if [[ "$#" -eq 0 ]]; then
    export KUBE_PS1_TOGGLE=off
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kube_toggle_off_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p "$(dirname $KUBE_PS1_DISABLE_PATH)"
    touch "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "${1}" != '-g' && "${1}" != '--global' ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _kube_toggle_off_usage
  else
    return
  fi
}

# Build our prompt
kube_ps1() {
  [[ -n "${KUBE_PS1_TOGGLE}" ]] && return
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && return

  local KUBE_PS1

  # Background Color
  if [[ -n "${KUBE_PS1_BG_COLOR}" ]]; then
    KUBE_PS1+="${_KUBE_PS1_BG_COLOR}"
  fi

  # Prefix
  if [[ -n "${KUBE_PS1_PREFIX}" ]]; then
    KUBE_PS1+="${KUBE_PS1_PREFIX}"
  fi

  # Symbol
  if [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
      KUBE_PS1+="${KUBE_PS1_SYMBOL}"
    else
      KUBE_PS1+="${_KUBE_PS1_SYMBOL_COLOR}${KUBE_PS1_SYMBOL}${KUBE_PS1_RESET_COLOR}"
    fi
    if [[ -n "${KUBE_PS1_SEPARATOR}" ]]; then
      KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
    fi
  fi

  # Cluster Context
  KUBE_PS1+="${_KUBE_PS1_CTX_COLOR}${KUBE_PS1_CONTEXT}${KUBE_PS1_RESET_COLOR}"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    if [[ -n "${KUBE_PS1_DIVIDER}" ]]; then
      KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    fi
    KUBE_PS1+="${_KUBE_PS1_NS_COLOR}${KUBE_PS1_NAMESPACE}${KUBE_PS1_RESET_COLOR}"
  fi

  # Suffix
  if [[ -n "${KUBE_PS1_SUFFIX}" ]]; then
    KUBE_PS1+="${KUBE_PS1_SUFFIX}"
  fi

  # Close Background color if defined
  if [[ -n "${KUBE_PS1_BG_COLOR}" ]]; then
    KUBE_PS1+="${_KUBE_PS1_BG_COLOR_CLOSE}"
  fi

  echo "${KUBE_PS1}"
}
