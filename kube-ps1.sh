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
KUBE_PS1_BINARY="${KUBE_PS1_BINARY:-kubectl}"
KUBE_PS1_SYMBOL_ENABLE="${KUBE_PS1_SYMBOL_ENABLE:-true}"
KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT:-\u2388 }"
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
elif [ "${BASH_VERSION-}" ]; then
  KUBE_PS1_SHELL="bash"
fi

_kube_ps1_init() {
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && KUBE_PS1_ENABLED=off

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

_kube_ps1_color_fg() {
  local ESC_OPEN
  local ESC_CLOSE
  local KUBE_PS1_FG_CODE
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    ESC_OPEN="%{"
    ESC_CLOSE="%}"
    case "${1}" in
      black|red|green|yellow|blue|cyan|white|magenta)
        KUBE_PS1_FG_CODE="%F{$1}";;
      [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        KUBE_PS1_FG_CODE="%F{$1}";;
      reset_color|"") KUBE_PS1_FG_CODE="%f";;
      *) KUBE_PS1_FG_CODE="%f";;
    esac
    echo "${ESC_OPEN}${KUBE_PS1_FG_CODE}${ESC_CLOSE}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    ESC_OPEN=$'\001'
    ESC_CLOSE=$'\002'
    if tput setaf 1 &> /dev/null; then
      case "${1}" in
        black) KUBE_PS1_FG_CODE="$(tput setaf 0)";;
        red) KUBE_PS1_FG_CODE="$(tput setaf 1)";;
        green) KUBE_PS1_FG_CODE="$(tput setaf 2)";;
        yellow) KUBE_PS1_FG_CODE="$(tput setaf 3)";;
        blue) KUBE_PS1_FG_CODE="$(tput setaf 4)";;
        magenta) KUBE_PS1_FG_CODE="$(tput setaf 5)";;
        cyan) KUBE_PS1_FG_CODE="$(tput setaf 6)";;
        white) KUBE_PS1_FG_CODE="$(tput setaf 7)";;
        reset_color|"") KUBE_PS1_FG_CODE=$'\033[39m';;
        [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
          KUBE_PS1_FG_CODE="$(tput setaf ${1})";;
        *) KUBE_PS1_FG_CODE=$'\033[39m';;
      esac
      echo "${ESC_OPEN}${KUBE_PS1_FG_CODE}${ESC_CLOSE}"
    else
      case "${1}" in
        black) KUBE_PS1_FG_CODE=$'\033[30m';;
        red) KUBE_PS1_FG_CODE=$'\033[31m';;
        green) KUBE_PS1_FG_CODE=$'\033[32m';;
        yellow) KUBE_PS1_FG_CODE=$'\033[33m';;
        blue) KUBE_PS1_FG_CODE=$'\033[34m';;
        magenta) KUBE_PS1_FG_CODE=$'\033[35m';;
        cyan) KUBE_PS1_FG_CODE=$'\033[36m';;
        white) KUBE_PS1_FG_CODE=$'\033[37m';;
        9[0-7]) KUBE_PS1_FG_CODE=$'\033['${1}m;;
        reset_color|"") KUBE_PS1_FG_CODE=$'\033[39m';;
        *) KUBE_PS1_FG_CODE=$'\033[39m';;
      esac
      echo ${ESC_OPEN}${KUBE_PS1_FG_CODE}${ESC_CLOSE}
    fi
  fi
}

_kube_ps1_color_bg() {
  local ESC_OPEN
  local ESC_CLOSE
  local KUBE_PS1_BG_CODE
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    ESC_OPEN="%{"
    ESC_CLOSE="%}"
    case "${1}" in
      black|red|green|yellow|blue|cyan|white|magenta)
        KUBE_PS1_BG_CODE="%K{$1}";;
      [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        KUBE_PS1_BG_CODE="%K{$1}";;
      bg_close) KUBE_PS1_BG_CODE="%k";;
      *) KUBE_PS1_BG_CODE="%K";;
    esac
    echo "${ESC_OPEN}${KUBE_PS1_BG_CODE}${ESC_CLOSE}"
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    ESC_OPEN=$'\001'
    ESC_CLOSE=$'\002'
    if tput setaf 1 &> /dev/null; then
      case "${1}" in
        black) KUBE_PS1_BG_CODE="$(tput setab 0)";;
        red) KUBE_PS1_BG_CODE="$(tput setab 1)";;
        green) KUBE_PS1_BG_CODE="$(tput setab 2)";;
        yellow) KUBE_PS1_BG_CODE="$(tput setab 3)";;
        blue) KUBE_PS1_BG_CODE="$(tput setab 4)";;
        magenta) KUBE_PS1_BG_CODE="$(tput setab 5)";;
        cyan) KUBE_PS1_BG_CODE="$(tput setab 6)";;
        white) KUBE_PS1_BG_CODE="$(tput setab 7)";;
        [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
          KUBE_PS1_BG_CODE="$(tput setab ${1})";;
        bg_close) KUBE_PS1_BG_CODE="$(tput sgr 0)";;
        *) KUBE_PS1_BG_CODE="$(tput sgr 0)";;
      esac
      echo ${ESC_OPEN}${KUBE_PS1_BG_CODE}${ESC_CLOSE}
    else
      case "${1}" in
        black) KUBE_PS1_BG_CODE=$'\033[40m';;
        red) KUBE_PS1_BG_CODE=$'\033[41m';;
        green) KUBE_PS1_BG_CODE=$'\033[42m';;
        yellow) KUBE_PS1_BG_CODE=$'\033[43m';;
        blue) KUBE_PS1_BG_CODE=$'\033[44m';;
        magenta) KUBE_PS1_BG_CODE=$'\033[45m';;
        cyan) KUBE_PS1_BG_CODE=$'\033[46m';;
        white) KUBE_PS1_BG_CODE=$'\033[47m';;
        10[0-7])KUBE_PS1_BG_CODE=$'\033['${1}m;;
        bg_close) KUBE_PS1_BG_CODE=$'\033[0m';;
        *) KUBE_PS1_BG_CODE=$'\033[0m';;
      esac
      echo ${ESC_OPEN}${KUBE_PS1_BG_CODE}${ESC_CLOSE}
    fi
  fi
}

_kube_ps1_binary_check() {
  command -v $1 >/dev/null
}

_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  case "${KUBE_PS1_SHELL}" in
    bash)
      if ((BASH_VERSINFO[0] >= 4)) && [[ $'\u2388 ' != "\\u2388 " ]]; then
        KUBE_PS1_SYMBOL=$'\u2388 '
        KUBE_PS1_SYMBOL_IMG=$'\u2638 '
      else
        KUBE_PS1_SYMBOL=$'\xE2\x8E\x88 '
        KUBE_PS1_SYMBOL_IMG=$'\xE2\x98\xB8 '
      fi
      ;;
    zsh)
      KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_DEFAULT}"
      KUBE_PS1_SYMBOL_IMG="\u2638 ";;
    *)
      KUBE_PS1_SYMBOL="k8s"
  esac

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    KUBE_PS1_SYMBOL="${KUBE_PS1_SYMBOL_IMG}"
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
  elif [[ "$KUBE_PS1_UNAME" == "Linux" ]]; then
    mtime=$(stat -c %Y "${file}")
  else
    mtime=$(stat -f %m "$file")
  fi

  [[ "${mtime}" -gt "${check_time}" ]]
}

_kube_ps1_update_cache() {
  [[ "${KUBE_PS1_ENABLED}" == "off" ]] && return

  if ! _kube_ps1_binary_check "${KUBE_PS1_BINARY}"; then
    # No ability to fetch context/namespace; display N/A.
    KUBE_PS1_CONTEXT="BINARY-N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  fi

  if [[ "${KUBECONFIG}" != "${KUBE_PS1_KUBECONFIG_CACHE}" ]]; then
    # User changed KUBECONFIG; unconditionally refetch.
    KUBE_PS1_KUBECONFIG_CACHE=${KUBECONFIG}
    _kube_ps1_get_context_ns
    return
  fi

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  local conf
  for conf in $(_kube_ps1_split : "${KUBECONFIG:-${HOME}/.kube/config}"); do
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

# Set kube-ps1 shell defaults
_kube_ps1_init

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
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeon_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f -- "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "$#" -ne 0 ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _kubeon_usage
    return
  fi

  KUBE_PS1_ENABLED=on
}

kubeoff() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kubeoff_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p -- "$(dirname "${KUBE_PS1_DISABLE_PATH}")"
    touch -- "${KUBE_PS1_DISABLE_PATH}"
  elif [[ $# -ne 0 ]]; then
    echo "error: unrecognized flag ${1}" >&2
    _kubeoff_usage
    return
  fi

  KUBE_PS1_ENABLED=off
}

# Build our prompt
kube_ps1() {
  [[ "${KUBE_PS1_ENABLED}" == "off" ]] && return

  local KUBE_PS1
  local KUBE_PS1_RESET_COLOR="$(_kube_ps1_color_fg reset_color)"

  # Background Color
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="$(_kube_ps1_color_bg ${KUBE_PS1_BG_COLOR})"

  # Prefix
  [[ -n "${KUBE_PS1_PREFIX}" ]] && KUBE_PS1+="${KUBE_PS1_PREFIX}"

  # Symbol
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_SYMBOL_COLOR)$(_kube_ps1_symbol)${KUBE_PS1_RESET_COLOR}"

  if [[ -n "${KUBE_PS1_SEPARATOR}" ]] && [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
  fi

  # Context
  KUBE_PS1+="$(_kube_ps1_color_fg $KUBE_PS1_CTX_COLOR)${KUBE_PS1_CONTEXT}${KUBE_PS1_RESET_COLOR}"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    if [[ -n "${KUBE_PS1_DIVIDER}" ]]; then
      KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    fi
    KUBE_PS1+="$(_kube_ps1_color_fg ${KUBE_PS1_NS_COLOR})${KUBE_PS1_NAMESPACE}${KUBE_PS1_RESET_COLOR}"
  fi

  # Suffix
  [[ -n "${KUBE_PS1_SUFFIX}" ]] && KUBE_PS1+="${KUBE_PS1_SUFFIX}"

  # Close Background color if defined
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="$(_kube_ps1_color_bg bg_close)"

  echo "${KUBE_PS1}"
}
