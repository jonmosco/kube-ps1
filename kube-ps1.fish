#!/usr/bin/env fish

# Kubernetes prompt helper for bash/zsh/fish
# Displays current context and namespace

# Copyright 2024 Jon Mosco
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
# $fish trace

if set -q _KUBE_PS1_BINARY
  set -l _KUBE_PS1_BINARY kubectl
end

if set -q _KUBE_PS1_SYMBOL_ENABLE
  set _KUBE_PS1_SYMBOL_ENABLE true
end

if set -q _KUBE_PS1_SYMBOL_PADDING
  set _KUBE_PS1_SYMBOL_PADDING false
end

if set -q _KUBE_PS1_SYMBOL_USE_IMG
  set _KUBE_PS1_SYMBOL_USE_IMG false
end

if set -q _KUBE_PS1_SYMBOL_OC_IMG
  set _KUBE_PS1_SYMBOL_OC_IMG false
end

if set -q _KUBE_PS1_NS_ENABLE
  set _KUBE_PS1_NS_ENABLE true
end

if set -q _KUBE_PS1_CONTEXT_ENABLE
  set _KUBE_PS1_CONTEXT_ENABLE true
end

if test -n _KUBE_PS1_PREFIX
  set -g _KUBE_PS1_PREFIX "("
end

if set -q _KUBE_PS1_SEPARATOR
  set -g _KUBE_PS1_SEPARATOR "|"
end

if set -q _KUBE_PS1_DIVIDER
  set -g _KUBE_PS1_DIVIDER ":"
end

if set -q _KUBE_PS1_SUFFIX
  set -g _KUBE_PS1_SUFFIX ")"
end

#  if set -q "$_KUBE_PS1_SYMBOL_COLOR"
#    set _KUBE_PS1_SYMBOL_COLOR blue
#  end

# KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR-red}"
# KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR-cyan}"
# KUBE_PS1_BG_COLOR="${KUBE_PS1_BG_COLOR}"

# set -g color_ctx (set_color $KUBE_PROMPT_COLOR_CTX)
# set -g color_ns (set_color $KUBE_PROMPT_COLOR_NS)

# KUBE_PS1_CLUSTER_FUNCTION="${KUBE_PS1_CLUSTER_FUNCTION}"
# KUBE_PS1_NAMESPACE_FUNCTION="${KUBE_PS1_NAMESPACE_FUNCTION}"

set -g  _KUBE_PS1_DISABLE_PATH $HOME/.kube/kube-ps1/disabled
set -g _KUBE_PS1_KUBECONFIG_CACHE KUBECONFIG
set -g _KUBE_PS1_LAST_TIME 0

# function kube_ps1_color_fg
# end

# function kube_ps1_color_bg
# end

function kube_ps1_binary_check
    command -q $1
end

## DONE ##
function _kube_ps1_split_config
    string split ":" $argv
end

## DONE ##
function _kube_ps1_file_newer_than
    set -l mtime
    set -l file $argv[1]
    set -l check_time $argv[2]

    # file modification time options from kube-ps1
    if stat -c "%s" /dev/null &> /dev/null
        # GNU stat
        set -l mtime (stat -L -c %Y "$file")
    else
        # BSD stat
        set -l mtime (stat -L -f %m "$file")
    end

    [ "$mtime" -gt "$check_time" ]
end

# TODO: Lots of work needed here
function kube_ps1_prompt_update
    set -l return_code $status

  [ "$KUBE_PS1_ENABLED" = "off" ] and return $return_code

  if ! _kube_ps1_binary_check "$KUBE_PS1_BINARY"
      # No ability to fetch context/namespace; display N/A.
      set -l KUBE_PS1_CONTEXT "BINARY-N/A"
      set -l KUBE_PS1_NAMESPACE "N/A"
      return $return_code
  end

  if [ "$KUBECONFIG" != "$_KUBE_PS1_KUBECONFIG_CACHE" ]
      # User changed KUBECONFIG; unconditionally refetch.
      set -l _KUBE_PS1_KUBECONFIG_CACHE $KUBECONFIG
      _kube_ps1_get_context_ns
      return $return_code
  end

  local conf
  local config_file_cache

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  set -l kubeconfig "$KUBECONFIG"
  if set -q "$kubeconfig"
      set kubeconfig "$HOME/.kube/config"
  end

  for conf in _kube_ps1_split_config "$kubeconfig"
      [ -r "$conf" ] or continue
      set -a config_file_cache conf
      if _kube_ps1_file_newer_than "$conf" "$_KUBE_PS1_LAST_TIME"
          _kube_ps1_get_context_ns
          return $return_code
      end
  end

  if [ "$config_file_cache" != "$_KUBE_PS1_CFGFILES_READ_CACHE" ]
      _kube_ps1_get_context_ns
      return $return_code
  end

  return $return_code
end

## DONE ##
function _kube_ps1_get_context
  if [ "$KUBE_PS1_CONTEXT_ENABLE" = true ]
      set -g _KUBE_PS1_CONTEXT $_KUBE_PS1_BINARY config current-context 2>/dev/null

      if not test -e "_KUBE_PS1_CONTEXT"
          set _KUBE_PS1_CONTEXT "N/A"
      end
  end
end

## DONE ##
function _kube_ps1_get_ns
    if [ "$KUBE_PS1_NS_ENABLE" = true ]
        set -g _KUBE_PS1_NAMESPACE $_KUBE_PS1_BINARY config view --minify --output 'jsonpath={..namespace}' 2>/dev/null

        if test -z "_KUBE_PS1_NAMESPACE"
            set _KUBE_PS1_NAMESPACE "N/A"
        end
    end
end

function kube_ps1_get_ctx_ns
  # Set the command time
  set -l _KUBE_PS1_LAST_TIME (date +%s)

  set -q KUBE_PS1_CONTEXT; or set -l KUBE_PS1_CONTEXT "N/A"
  set -q KUBE_PS1_NAMESPACE; or set -l KUBE_PS1_NAMESPACE "N/A"

  # Cache which cfgfiles we can read in case they change.
  set -l conf

  set -l kubeconfig "$KUBECONFIG"
  if set -q "$kubeconfig"
      set -l kubeconfig "$HOME/.kube/config"
  end

  # _KUBE_PS1_CFGFILES_READ_CACHE=
  for conf in _kube_ps1_split_config $kubeconfig
      [ -r $conf ]; and set -a conf _KUBE_PS1_CFGFILES_READ_CACHE
  end

  _kube_ps1_get_context
  _kube_ps1_get_ns

  set -g KUBE_PS1_CONTEXT "N/A"
  set -g KUBE_PS1_NAMESPACE "N/A"
end

function _kube_ps1_symbol
  [ "$KUBE_PS1_SYMBOL_ENABLE" = false ]; and return

  set -l KUBE_PS1_SYMBOL \u2638

  if [ "$KUBE_PS1_SYMBOL_USE_IMG" = true ]
      set -l KUBE_PS1_SYMBOL "$KUBE_PS1_SYMBOL_IMG"
  end

  # OpenShift glyph
  # NOTE: this requires a patched "Nerd" font to work
  # https://www.nerdfonts.com/
  if [ "$KUBE_PS1_SYMBOL_OC_IMG" = true ]
      set -l KUBE_PS1_SYMBOL \ue7b7
  end

  if [ "$KUBE_PS1_SYMBOL_PADDING" = true ]
      echo "$KUBE_PS1_SYMBOL "
  else
      echo "$KUBE_PS1_SYMBOL"
  end
end

## DONE ##
function _kubeon_usage
    echo "Toggle kube-ps1 prompt on"
    echo
    echo "Usage: kubeon [-g | --global] [-h | --help]"
    echo
    echo "With no arguments, turn oon kube-ps1 status for this shell instance (default)."
    echo
    echo "  -g --global  turn on kube-ps1 status globally"
    echo "  -h --help    print this message"
end

## DONE ##
function _kubeoff_usage
    echo "Toggle kube-ps1 prompt off"
    echo
    echo "Usage: kubeoff [-g | --global] [-h | --help]"
    echo
    echo "With no arguments, turn off kube-ps1 status for this shell instance (default)."
    echo
    echo "  -g --global turn off kube-ps1 status globally"
    echo "  -h --help   print this message"
end

function kube_ps1_on
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeon_usage
        return 0
    end

    if set -ql _flag_second
        rm -f -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g _KUBE_PS1_ENABLED on
end

function kube_ps1_off
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeon_usage
        return 0
    end

    if set -ql _flag_second
        mkdir -p -- "(path basename "$_KUBE_PS1_DISABLE_PATH")"
        touch -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g _KUBE_PS1_ENABLED off
end

# Build our prompt
function kube_ps1

    echo "$_KUBE_PS1_PREFIX" \
        (_kube_ps1_symbol) \
        "$_KUBE_PS1_SEPARATOR" \
        (_kube_ps1_get_context) \
        "$_KUBE_PS1_DIVIDER" \
        (_kube_ps1_get_ns) \
        "$_KUBE_PS1_SUFFIX"

      # echo (set_color blue)$KUBECTL_PROMPT_ICON" "(set_color cyan)"($context"(set_color white)"$KUBECTL_PROMPT_SEPARATOR"(set_color yellow)"$ns)"

end
