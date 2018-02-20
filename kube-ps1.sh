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
KUBE_PS1_BINARY="${KUBE_PS1_BINARY=kubectl}"
KUBE_PS1_SYMBOL_ENABLE="${KUBE_PS1_SYMBOL_ENABLE:-true}"
KUBE_PS1_SYMBOL_DEFAULT=${KUBE_PS1_SYMBOL_DEFAULT:-$'\u2388 '}
KUBE_PS1_SYMBOL_USE_IMG="${KUBE_PS1_SYMBOL_USE_IMG:-false}"
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
KUBE_PS1_PREFIX="${KUBE_PS1_PREFIX-(}"
KUBE_PS1_SEPARATOR="${KUBE_PS1_SEPARATOR-|}"
KUBE_PS1_DIVIDER="${KUBE_PS1_DIVIDER-:}"
KUBE_PS1_SUFFIX="${KUBE_PS1_SUFFIX-)}"
KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_SYMBOL_COLOR-blue}"
KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR-red}"
KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR-cyan}"
KUBE_PS1_BG_COLOR="${KUBE_PS1_BG_COLOR}"
KUBE_PS1_KUBECONFIG_CACHE="${KUBECONFIG}"
KUBE_PS1_DISABLE_PATH="${HOME}/.kube/kube-ps1/disabled"
KUBE_PS1_UNAME=$(uname)
KUBE_PS1_LAST_TIME=0

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  KUBE_PS1_SHELL="zsh"
  esc_open="%{"
  esc_close="%}"
  fg_open="%F"
  bg_open="%K"
elif [ "${BASH_VERSION-}" ]; then
  KUBE_PS1_SHELL="bash"
  esc_open=$'\001'
  esc_close=$'\002'
  color_fg_seq=$'\033[3'
  color_bg_seq=$'\033[4'
fi

_kube_ps1_shell_settings() {
  case "${KUBE_PS1_SHELL}" in
    "zsh")
      setopt PROMPT_SUBST
      autoload -U add-zsh-hook
      add-zsh-hook precmd _kube_ps1_update_cache
      zmodload zsh/stat
      zmodload zsh/datetime
      ;;
    "bash")
      PROMPT_COMMAND="_kube_ps1_update_cache;${PROMPT_COMMAND:-:}"
      ;;
  esac
}

_kube_ps1_color() {
  local color_code
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    case "${1}" in
      black|red|green|yellow|blue|cyan|white|magenta)
        color_code="{$1}";;
      0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        color_code="{$1}";;
      reset_fg_color) color_code="${esc_open}%f${esc_close}";;
      reset_bg_color) color_code="${esc_open}%k${esc_close}";;
    esac
  else
    case "${1}" in
      black) color_code=0;;
      red) color_code=1;;
      green) color_code=2;;
      yellow) color_code=3;;
      blue) color_code=4;;
      magenta) color_code=5;;
      cyan) color_code=6;;
      white) color_code=7;;
      [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        color_code="${1}";;
      reset_fg_color) color_code=${esc_open}$'\033[39m'${esc_close};;
      reset_bg_color) color_code=${esc_open}$'\033[49m'${esc_close};;
    esac
  fi
  echo "${color_code}"
}

_kube_ps1_color_fg() {
  local fg_code
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    fg_code="${esc_open}${fg_open}$(_kube_ps1_color "${1}")${esc_close}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      fg_code="${esc_open}$(tput setaf "$(_kube_ps1_color ${1})")${esc_close}"
    else
      fg_code="${esc_open}${color_fg_seq}$(_kube_ps1_color ${1})m${esc_close}"
    fi
  fi
  echo "${fg_code}"
}

_kube_ps1_color_bg() {
  local bg_code
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    bg_code="${esc_open}${bg_open}$(_kube_ps1_color "${1}")${esc_close}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      bg_code="${esc_open}$(tput setab "$(_kube_ps1_color ${1})")${esc_close}"
    else
      bg_code="${esc_open}${color_bg_seq}$(kube_ps1_color ${1})m${esc_close}"
    fi
  fi
  echo "${bg_code}"
}

_kube_ps1_binary_check() {
  command -v $1 >/dev/null
}

_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  local _KUBE_PS1_SYMBOL_IMG
  local _KUBE_PS1_SYMBOL_DEFAULT

  # TODO: Test terminal capabilities
  #       If LANG is set to POSIX, the hex will
  #       work.
  # [[ "$LC_CTYPE $LC_ALL" =~ "UTF" && $TERM != "linux" ]]
  #       Bash only supports \u \U since 4.2
  if [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] >= 4)); then
      _KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT}"
      _KUBE_PS1_SYMBOL_IMG=$'\u2638 '
    else
      _KUBE_PS1_SYMBOL_DEFAULT=$'\xE2\x8E\x88 '
      _KUBE_PS1_SYMBOL_IMG=$'\xE2\x98\xB8 '
    fi
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    _KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT}"
    _KUBE_PS1_SYMBOL_IMG=$'\u2638 '
  else
    _KUBE_PS1_SYMBOL_DEFAULT="k8s"
  fi

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_IMG}"
  else
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_DEFAULT}"
  fi

  echo "${KUBE_PS1_SYMBOL}"
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
  if ! _kube_ps1_enabled; then
    return
  fi

  if ! _kube_ps1_binary_check "${KUBE_PS1_BINARY}"; then
    KUBE_PS1_CONTEXT="BINARY-N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  fi

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
  if [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] >= 4)); then
      KUBE_PS1_LAST_TIME=$(printf '%(%s)T')
    else
      KUBE_PS1_LAST_TIME=$(date +%s)
    fi
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    KUBE_PS1_LAST_TIME=$EPOCHSECONDS
  fi

  KUBE_PS1_CONTEXT="$(${KUBE_PS1_BINARY} config current-context 2>/dev/null)"
  if [[ -z "${KUBE_PS1_CONTEXT}" ]]; then
    KUBE_PS1_CONTEXT="N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  elif [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1_NAMESPACE="$(${KUBE_PS1_BINARY} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
    # Set namespace to 'default' if it is not defined
    KUBE_PS1_NAMESPACE="${KUBE_PS1_NAMESPACE:-default}"
  fi
}

# Set shell options
_kube_ps1_shell_settings

_kubeon_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt on

Usage: kubeon [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global  turn on kube-ps1 status globally
  -h --help    print this message
EOF
}

_kubeoff_usage() {
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
    KUBE_PS1_ENABLED=on
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeon_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f "${KUBE_PS1_DISABLE_PATH}"
  else
    echo -e "error: unrecognized flag ${1}\\n"
    _kubeon_usage
    return
  fi
}


kubeoff() {
  if [[ "$#" -eq 0 ]]; then
    KUBE_PS1_ENABLED=off
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeoff_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p "$(dirname $KUBE_PS1_DISABLE_PATH)"
    touch "${KUBE_PS1_DISABLE_PATH}"
  else
    echo -e "error: unrecognized flag ${1}\\n"
    _kubeoff_usage
    return
  fi
}

_kube_ps1_enabled() {
  if [[ "${KUBE_PS1_ENABLED}" == "on" ]]; then
    :
  elif [[ "${KUBE_PS1_ENABLED}" == "off" ]] || [[ -f "${KUBE_PS1_DISABLE_PATH}" ]]; then
    return 1
  fi
  return 0
}

# Build our prompt
kube_ps1() {
  if ! _kube_ps1_enabled; then
    return
  fi

  local KUBE_PS1

  # Background Color
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="$(_kube_ps1_color_bg ${KUBE_PS1_BG_COLOR})"

  # Prefix
  [[ -n "${KUBE_PS1_PREFIX}" ]] && KUBE_PS1+="${KUBE_PS1_PREFIX}"

  # Symbol
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_SYMBOL_COLOR)$(_kube_ps1_symbol)$(_kube_ps1_color reset_fg_color)"

  if [[ -n "${KUBE_PS1_SEPARATOR}" ]] && [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
 fi

  # Context
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_CTX_COLOR)${KUBE_PS1_CONTEXT}$(_kube_ps1_color reset_fg_color)"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    if [[ -n "${KUBE_PS1_DIVIDER}" ]]; then
      KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    fi
    KUBE_PS1+="$(_kube_ps1_color_fg ${KUBE_PS1_NS_COLOR})${KUBE_PS1_NAMESPACE}$(_kube_ps1_color reset_fg_color)"
  fi

  # Suffix
  [[ -n "${KUBE_PS1_SUFFIX}" ]] && KUBE_PS1+="${KUBE_PS1_SUFFIX}"

  # Close Background color if defined
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="$(_kube_ps1_color reset_bg_color)"

  echo "${KUBE_PS1}"
}
