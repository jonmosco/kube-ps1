#!/usr/bin/env fish

# Kubernetes prompt info for bash, fish, and zsh
# Displays current context and namespace

# Copyright 2026 Jon Mosco
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

if not set -q KUBE_PS1_BINARY
    set -g KUBE_PS1_BINARY kubectl
end

if not set -q KUBE_PS1_SYMBOL_ENABLE
    set -g KUBE_PS1_SYMBOL_ENABLE true
end

if not set -q KUBE_PS1_SYMBOL_PADDING
    set -g KUBE_PS1_SYMBOL_PADDING false
end

if not set -q KUBE_PS1_SYMBOL_USE_IMG
    set -g KUBE_PS1_SYMBOL_USE_IMG false
end

if not set -q KUBE_PS1_SYMBOL_OC_IMG
    set -g KUBE_PS1_SYMBOL_OC_IMG false
end

if not set -q KUBE_PS1_NS_ENABLE
    set -g KUBE_PS1_NS_ENABLE true
end

if not set -q KUBE_PS1_CONTEXT_ENABLE
    set -g KUBE_PS1_CONTEXT_ENABLE true
end

if not set -q KUBE_PS1_PREFIX
    set -g KUBE_PS1_PREFIX "("
end

if not set -q KUBE_PS1_SEPARATOR
    set -g KUBE_PS1_SEPARATOR "|"
end

if not set -q KUBE_PS1_DIVIDER
    set -g KUBE_PS1_DIVIDER ":"
end

if not set -q KUBE_PS1_SUFFIX
    set -g KUBE_PS1_SUFFIX ")"
end

if not set -q KUBE_PS1_HIDE_IF_NOCONTEXT
    set -g KUBE_PS1_HIDE_IF_NOCONTEXT false
end

if not set -q KUBE_PS1_SYMBOL_IMG
    set -g KUBE_PS1_SYMBOL_IMG "☸️"
end

if not set -q KUBE_PS1_CONTEXT
    set -g KUBE_PS1_CONTEXT "N/A"
end

if not set -q KUBE_PS1_NAMESPACE
    set -g KUBE_PS1_NAMESPACE "N/A"
end

if not set -q KUBE_PS1_ENABLED
    set -g KUBE_PS1_ENABLED on
end

if not set -q _KUBE_PS1_STAT_TYPE
    if stat -c "%s" /dev/null &>/dev/null
        set -g _KUBE_PS1_STAT_TYPE gnu
    else
        set -g _KUBE_PS1_STAT_TYPE bsd
    end
end

if not set -q KUBE_PS1_SYMBOL_COLOR
    set -g KUBE_PS1_SYMBOL_COLOR blue
end

if not set -q KUBE_PS1_CTX_COLOR
    set -g KUBE_PS1_CTX_COLOR red
end

if not set -q KUBE_PS1_NS_COLOR
    set -g KUBE_PS1_NS_COLOR cyan
end

if not set -q KUBE_PS1_PREFIX_COLOR
    set -g KUBE_PS1_PREFIX_COLOR
end

if not set -q KUBE_PS1_SUFFIX_COLOR
    set -g KUBE_PS1_SUFFIX_COLOR
end

if not set -q KUBE_PS1_BG_COLOR
    set -g KUBE_PS1_BG_COLOR
end

set -g _KUBE_PS1_DISABLE_PATH $HOME/.kube/kube-ps1/disabled
if test -f "$_KUBE_PS1_DISABLE_PATH"
    set -g KUBE_PS1_ENABLED off
end

set -g _KUBE_PS1_KUBECONFIG_CACHE "$KUBECONFIG"
set -g _KUBE_PS1_LAST_TIME 0
set -g _KUBE_PS1_CFGFILES_READ_CACHE

function _kube_ps1_color_fg
    set -l color $argv[1]
    set -l text $argv[2]
    if test -n "$color"
        set_color $color
        echo -n "$text"
        set_color normal
    else
        echo -n "$text"
    end
end

function _kube_ps1_binary_check
    command -q $argv[1]
end

function _kube_ps1_split_config
    string split ":" -- "$argv[1]"
end

function _kube_ps1_get_kubeconfig
    if test -n "$KUBECONFIG"
        _kube_ps1_split_config "$KUBECONFIG"
    else
        echo "$HOME/.kube/config"
    end
end

function _kube_ps1_file_newer_than
    set -l mtime
    set -l file $argv[1]
    set -l check_time $argv[2]

    if type -q path
        set mtime (path mtime -- $file)
    else
        if test "$_KUBE_PS1_STAT_TYPE" = gnu
            set mtime (stat -L -c %Y -- "$file")
        else
            set mtime (stat -L -f %m -- "$file")
        end
    end

    test "$mtime" -gt "$check_time"
end

function _kube_ps1_prompt_update
    set -l return_code $status

    test "$KUBE_PS1_ENABLED" = "off"; and return $return_code

    if not _kube_ps1_binary_check "$KUBE_PS1_BINARY"
        # No ability to fetch context/namespace; display N/A.
        set -g KUBE_PS1_CONTEXT "BINARY-N/A"
        set -g KUBE_PS1_NAMESPACE "N/A"
        return $return_code
    end

    if test "$KUBECONFIG" != "$_KUBE_PS1_KUBECONFIG_CACHE"
        # User changed KUBECONFIG; unconditionally refetch.
        set -g _KUBE_PS1_KUBECONFIG_CACHE "$KUBECONFIG"
        _kube_ps1_get_ctx_ns
        return $return_code
    end

    set -l conf
    set -l config_file_cache

    for conf in (_kube_ps1_get_kubeconfig)
        test -r "$conf"; or continue
        set -a config_file_cache "$conf"
        if _kube_ps1_file_newer_than "$conf" "$_KUBE_PS1_LAST_TIME"
            _kube_ps1_get_ctx_ns
            return $return_code
        end
    end

    if test "$config_file_cache" != "$_KUBE_PS1_CFGFILES_READ_CACHE"
        _kube_ps1_get_ctx_ns
        return $return_code
    end

    return $return_code
end

function _kube_ps1_get_context
    if test "$KUBE_PS1_CONTEXT_ENABLE" = true
        set -g KUBE_PS1_CONTEXT ($KUBE_PS1_BINARY config current-context 2>/dev/null)

        if test -z "$KUBE_PS1_CONTEXT"
            set -g KUBE_PS1_CONTEXT "N/A"
        end

        if test -n "$KUBE_PS1_CLUSTER_FUNCTION"
            if functions -q "$KUBE_PS1_CLUSTER_FUNCTION"
                set -g KUBE_PS1_CONTEXT ($KUBE_PS1_CLUSTER_FUNCTION "$KUBE_PS1_CONTEXT")
            end
        end
    else
        set -g KUBE_PS1_CONTEXT ""
    end
end

function _kube_ps1_get_ns
    if test "$KUBE_PS1_NS_ENABLE" = true
        set -g KUBE_PS1_NAMESPACE ($KUBE_PS1_BINARY config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)

        if test -z "$KUBE_PS1_NAMESPACE"
            set -g KUBE_PS1_NAMESPACE "N/A"
        end

        if test -n "$KUBE_PS1_NAMESPACE_FUNCTION"
            if functions -q "$KUBE_PS1_NAMESPACE_FUNCTION"
                set -g KUBE_PS1_NAMESPACE ($KUBE_PS1_NAMESPACE_FUNCTION "$KUBE_PS1_NAMESPACE")
            end
        end
    else
        set -g KUBE_PS1_NAMESPACE ""
    end
end

function _kube_ps1_get_ctx_ns
    # Set the command time
    set -g _KUBE_PS1_LAST_TIME (date +%s)

    # Cache which cfgfiles we can read in case they change.
    set -l conf
    set -g _KUBE_PS1_CFGFILES_READ_CACHE

    for conf in (_kube_ps1_get_kubeconfig)
        if test -r "$conf"
            set -a _KUBE_PS1_CFGFILES_READ_CACHE "$conf"
        end
    end

    _kube_ps1_get_context
    _kube_ps1_get_ns
end

function _kube_ps1_symbol
    test "$KUBE_PS1_SYMBOL_ENABLE" = false; and return

    set -l KUBE_PS1_SYMBOL \u2638
    set -l symbol_color "$KUBE_PS1_SYMBOL_COLOR"

    if test "$KUBE_PS1_SYMBOL_USE_IMG" = true
        set KUBE_PS1_SYMBOL "$KUBE_PS1_SYMBOL_IMG"
    end

    # OpenShift glyph
    # NOTE: this requires a patched "Nerd" font to work
    # https://www.nerdfonts.com/
    if test "$KUBE_PS1_SYMBOL_OC_IMG" = true
        set KUBE_PS1_SYMBOL \ue7b7
        set symbol_color red
    end

    set -l output (_kube_ps1_color_fg "$symbol_color" "$KUBE_PS1_SYMBOL")

    if test "$KUBE_PS1_SYMBOL_PADDING" = true
        printf "%s " "$output"
    else
        printf "%s" "$output"
    end
end

function _kubeon_usage
    echo "Toggle kube-ps1 prompt on"
    echo
    echo "Usage: kubeon [-g | --global] [-h | --help]"
    echo
    echo "With no arguments, turn on kube-ps1 status for this shell instance (default)."
    echo
    echo "  -g --global  turn on kube-ps1 status globally"
    echo "  -h --help    print this message"
end

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

function kubeon --description "Turn on kube-ps1 prompt status"
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeon_usage
        return 0
    end

    if set -ql _flag_global
        rm -f -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g KUBE_PS1_ENABLED on
end

function kubeoff --description "Turn off kube-ps1 prompt status"
    argparse h/help g/global -- $argv
    or return

    if set -ql _flag_help
        _kubeoff_usage
        return 0
    end

    if set -ql _flag_global
        mkdir -p -- (dirname "$_KUBE_PS1_DISABLE_PATH")
        touch -- "$_KUBE_PS1_DISABLE_PATH"
    end

    set -g KUBE_PS1_ENABLED off
end

# Build our prompt
function kube_ps1 --description "Print the Kubernetes prompt status"
    set -l last_status $status
    _kube_ps1_prompt_update

    test "$KUBE_PS1_ENABLED" = "off"; and return $last_status

    if test "$KUBE_PS1_CONTEXT" = "N/A"; and test "$KUBE_PS1_HIDE_IF_NOCONTEXT" = true
        return $last_status
    end


    # Background color
    if test -n "$KUBE_PS1_BG_COLOR"
        set_color -b "$KUBE_PS1_BG_COLOR"
    end

    set -l kube_ps1 ""

    # Prefix
    if test -n "$KUBE_PS1_PREFIX"
        set -l prefix (_kube_ps1_color_fg "$KUBE_PS1_PREFIX_COLOR" "$KUBE_PS1_PREFIX")
        set kube_ps1 "$kube_ps1$prefix"
    end

    # Symbol
    set -l symbol (_kube_ps1_symbol)
    if test -n "$symbol"
        set kube_ps1 "$kube_ps1$symbol"
        if test -n "$KUBE_PS1_SEPARATOR"
            if test "$KUBE_PS1_CONTEXT_ENABLE" = true; or test "$KUBE_PS1_NS_ENABLE" = true
                set kube_ps1 "$kube_ps1$KUBE_PS1_SEPARATOR"
            end
        end
    end

    # Context
    if test "$KUBE_PS1_CONTEXT_ENABLE" = true; and test -n "$KUBE_PS1_CONTEXT"
        set -l ctx (_kube_ps1_color_fg "$KUBE_PS1_CTX_COLOR" "$KUBE_PS1_CONTEXT")
        set kube_ps1 "$kube_ps1$ctx"
    end

    # Namespace
    if test "$KUBE_PS1_NS_ENABLE" = true; and test -n "$KUBE_PS1_NAMESPACE"
        if test "$KUBE_PS1_CONTEXT_ENABLE" = true; and test -n "$KUBE_PS1_CONTEXT"
            if test -n "$KUBE_PS1_DIVIDER"
                set kube_ps1 "$kube_ps1$KUBE_PS1_DIVIDER"
            end
        end
        set -l ns (_kube_ps1_color_fg "$KUBE_PS1_NS_COLOR" "$KUBE_PS1_NAMESPACE")
        set kube_ps1 "$kube_ps1$ns"
    end

    # Suffix
    if test -n "$KUBE_PS1_SUFFIX"
        set -l suffix (_kube_ps1_color_fg "$KUBE_PS1_SUFFIX_COLOR" "$KUBE_PS1_SUFFIX")
        set kube_ps1 "$kube_ps1$suffix"
    end

    printf "%s" "$kube_ps1"

    # Reset background color
    if test -n "$KUBE_PS1_BG_COLOR"
        set_color normal
    end
end
