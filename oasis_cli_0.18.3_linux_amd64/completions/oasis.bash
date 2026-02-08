# bash completion for oasis                                -*- shell-script -*-

__oasis_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__oasis_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__oasis_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__oasis_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__oasis_handle_go_custom_completion()
{
    __oasis_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly oasis allows handling aliases
    args=("${words[@]:1}")
    # Disable ActiveHelp which is not supported for bash completion v1
    requestComp="OASIS_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __oasis_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __oasis_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __oasis_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __oasis_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __oasis_debug "${FUNCNAME[0]}: the completions are: ${out}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __oasis_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __oasis_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __oasis_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __oasis_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out}")
        if [ -n "$subdir" ]; then
            __oasis_debug "Listing directories in $subdir"
            __oasis_handle_subdirs_in_dir_flag "$subdir"
        else
            __oasis_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out}" -- "$cur")
    fi
}

__oasis_handle_reply()
{
    __oasis_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __oasis_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi

            if [[ -z "${flag_parsing_disabled}" ]]; then
                # If flag parsing is enabled, we have completed the flags and can return.
                # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
                # to possibly call handle_go_custom_completion.
                return 0;
            fi
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __oasis_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __oasis_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        if declare -F __oasis_custom_func >/dev/null; then
            # try command name qualified custom func
            __oasis_custom_func
        else
            # otherwise fall back to unqualified for compatibility
            declare -F __custom_func >/dev/null && __custom_func
        fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__oasis_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__oasis_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__oasis_handle_flag()
{
    __oasis_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __oasis_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __oasis_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __oasis_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __oasis_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __oasis_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__oasis_handle_noun()
{
    __oasis_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __oasis_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __oasis_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__oasis_handle_command()
{
    __oasis_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_oasis_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __oasis_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__oasis_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __oasis_handle_reply
        return
    fi
    __oasis_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __oasis_handle_flag
    elif __oasis_contains_word "${words[c]}" "${commands[@]}"; then
        __oasis_handle_command
    elif [[ $c -eq 0 ]]; then
        __oasis_handle_command
    elif __oasis_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __oasis_handle_command
        else
            __oasis_handle_noun
        fi
    else
        __oasis_handle_noun
    fi
    __oasis_handle_word
}

_oasis_account_allow()
{
    last_command="oasis_account_allow"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_amend-commission-schedule()
{
    last_command="oasis_account_amend-commission-schedule"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--bounds=")
    two_word_flags+=("--bounds")
    local_nonpersistent_flags+=("--bounds")
    local_nonpersistent_flags+=("--bounds=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--rates=")
    two_word_flags+=("--rates")
    local_nonpersistent_flags+=("--rates")
    local_nonpersistent_flags+=("--rates=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_burn()
{
    last_command="oasis_account_burn"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_delegate()
{
    last_command="oasis_account_delegate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_deposit()
{
    last_command="oasis_account_deposit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_entity_deregister()
{
    last_command="oasis_account_entity_deregister"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_entity_init()
{
    last_command="oasis_account_entity_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_entity_metadata-update()
{
    last_command="oasis_account_entity_metadata-update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--registry-dir=")
    two_word_flags+=("--registry-dir")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--registry-dir")
    local_nonpersistent_flags+=("--registry-dir=")
    local_nonpersistent_flags+=("-r")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_entity_register()
{
    last_command="oasis_account_entity_register"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_entity()
{
    last_command="oasis_account_entity"

    command_aliases=()

    commands=()
    commands+=("deregister")
    commands+=("init")
    commands+=("metadata-update")
    commands+=("register")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_from-public-key()
{
    last_command="oasis_account_from-public-key"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_node-unfreeze()
{
    last_command="oasis_account_node-unfreeze"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_account_show()
{
    last_command="oasis_account_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--height=")
    two_word_flags+=("--height")
    local_nonpersistent_flags+=("--height")
    local_nonpersistent_flags+=("--height=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--show-delegations")
    local_nonpersistent_flags+=("--show-delegations")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_transfer()
{
    last_command="oasis_account_transfer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--subtract-fee")
    local_nonpersistent_flags+=("--subtract-fee")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_undelegate()
{
    last_command="oasis_account_undelegate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account_withdraw()
{
    last_command="oasis_account_withdraw"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--subtract-fee")
    local_nonpersistent_flags+=("--subtract-fee")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_account()
{
    last_command="oasis_account"

    command_aliases=()

    commands=()
    commands+=("allow")
    commands+=("amend-commission-schedule")
    commands+=("burn")
    commands+=("delegate")
    commands+=("deposit")
    commands+=("entity")
    commands+=("from-public-key")
    commands+=("node-unfreeze")
    commands+=("show")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("b")
        aliashash["b"]="show"
        command_aliases+=("balance")
        aliashash["balance"]="show"
        command_aliases+=("s")
        aliashash["s"]="show"
    fi
    commands+=("transfer")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("t")
        aliashash["t"]="transfer"
    fi
    commands+=("undelegate")
    commands+=("withdraw")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_addressbook_add()
{
    last_command="oasis_addressbook_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_addressbook_list()
{
    last_command="oasis_addressbook_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_addressbook_remove()
{
    last_command="oasis_addressbook_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_addressbook_rename()
{
    last_command="oasis_addressbook_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_addressbook_show()
{
    last_command="oasis_addressbook_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_addressbook()
{
    last_command="oasis_addressbook"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("rename")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("mv")
        aliashash["mv"]="rename"
    fi
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_completion()
{
    last_command="oasis_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_oasis_contract_call()
{
    last_command="oasis_contract_call"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--tokens=")
    two_word_flags+=("--tokens")
    local_nonpersistent_flags+=("--tokens")
    local_nonpersistent_flags+=("--tokens=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_change-upgrade-policy()
{
    last_command="oasis_contract_change-upgrade-policy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_dump-code()
{
    last_command="oasis_contract_dump-code"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_instantiate()
{
    last_command="oasis_contract_instantiate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--tokens=")
    two_word_flags+=("--tokens")
    local_nonpersistent_flags+=("--tokens")
    local_nonpersistent_flags+=("--tokens=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--upgrades-policy=")
    two_word_flags+=("--upgrades-policy")
    local_nonpersistent_flags+=("--upgrades-policy")
    local_nonpersistent_flags+=("--upgrades-policy=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_show()
{
    last_command="oasis_contract_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_show-code()
{
    last_command="oasis_contract_show-code"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_storage_dump()
{
    last_command="oasis_contract_storage_dump"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--offset=")
    two_word_flags+=("--offset")
    local_nonpersistent_flags+=("--offset")
    local_nonpersistent_flags+=("--offset=")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_storage_get()
{
    last_command="oasis_contract_storage_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_storage()
{
    last_command="oasis_contract_storage"

    command_aliases=()

    commands=()
    commands+=("dump")
    commands+=("get")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract_upload()
{
    last_command="oasis_contract_upload"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--instantiate-policy=")
    two_word_flags+=("--instantiate-policy")
    local_nonpersistent_flags+=("--instantiate-policy")
    local_nonpersistent_flags+=("--instantiate-policy=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_contract()
{
    last_command="oasis_contract"

    command_aliases=()

    commands=()
    commands+=("call")
    commands+=("change-upgrade-policy")
    commands+=("dump-code")
    commands+=("instantiate")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("inst")
        aliashash["inst"]="instantiate"
    fi
    commands+=("show")
    commands+=("show-code")
    commands+=("storage")
    commands+=("upload")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_help()
{
    last_command="oasis_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_add()
{
    last_command="oasis_network_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_add-local()
{
    last_command="oasis_network_add-local"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    two_word_flags+=("--description")
    local_nonpersistent_flags+=("--description")
    local_nonpersistent_flags+=("--description=")
    flags+=("--num-decimals=")
    two_word_flags+=("--num-decimals")
    local_nonpersistent_flags+=("--num-decimals")
    local_nonpersistent_flags+=("--num-decimals=")
    flags+=("--symbol=")
    two_word_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_cast-vote()
{
    last_command="oasis_network_governance_cast-vote"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_governance_create-proposal_cancel-upgrade()
{
    last_command="oasis_network_governance_create-proposal_cancel-upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_create-proposal_parameter-change()
{
    last_command="oasis_network_governance_create-proposal_parameter-change"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_create-proposal_upgrade()
{
    last_command="oasis_network_governance_create-proposal_upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_create-proposal()
{
    last_command="oasis_network_governance_create-proposal"

    command_aliases=()

    commands=()
    commands+=("cancel-upgrade")
    commands+=("parameter-change")
    commands+=("upgrade")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_list()
{
    last_command="oasis_network_governance_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--height=")
    two_word_flags+=("--height")
    local_nonpersistent_flags+=("--height")
    local_nonpersistent_flags+=("--height=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance_show()
{
    last_command="oasis_network_governance_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--height=")
    two_word_flags+=("--height")
    local_nonpersistent_flags+=("--height")
    local_nonpersistent_flags+=("--height=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--show-votes")
    local_nonpersistent_flags+=("--show-votes")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_governance()
{
    last_command="oasis_network_governance"

    command_aliases=()

    commands=()
    commands+=("cast-vote")
    commands+=("create-proposal")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_list()
{
    last_command="oasis_network_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_remove()
{
    last_command="oasis_network_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_set-chain-context()
{
    last_command="oasis_network_set-chain-context"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_set-default()
{
    last_command="oasis_network_set-default"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_set-rpc()
{
    last_command="oasis_network_set-rpc"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_network_show()
{
    last_command="oasis_network_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--height=")
    two_word_flags+=("--height")
    local_nonpersistent_flags+=("--height")
    local_nonpersistent_flags+=("--height=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_status()
{
    last_command="oasis_network_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network_trust()
{
    last_command="oasis_network_trust"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_network()
{
    last_command="oasis_network"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("add-local")
    commands+=("governance")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("gov")
        aliashash["gov"]="governance"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("set-chain-context")
    commands+=("set-default")
    commands+=("set-rpc")
    commands+=("show")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="show"
    fi
    commands+=("status")
    commands+=("trust")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime_add()
{
    last_command="oasis_paratime_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    two_word_flags+=("--description")
    local_nonpersistent_flags+=("--description")
    local_nonpersistent_flags+=("--description=")
    flags+=("--num-decimals=")
    two_word_flags+=("--num-decimals")
    local_nonpersistent_flags+=("--num-decimals")
    local_nonpersistent_flags+=("--num-decimals=")
    flags+=("--symbol=")
    two_word_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_denomination_remove()
{
    last_command="oasis_paratime_denomination_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_denomination_set()
{
    last_command="oasis_paratime_denomination_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--symbol=")
    two_word_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol")
    local_nonpersistent_flags+=("--symbol=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_denomination_set-native()
{
    last_command="oasis_paratime_denomination_set-native"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_denomination()
{
    last_command="oasis_paratime_denomination"

    command_aliases=()

    commands=()
    commands+=("remove")
    commands+=("set")
    commands+=("set-native")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime_list()
{
    last_command="oasis_paratime_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime_register()
{
    last_command="oasis_paratime_register"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime_remove()
{
    last_command="oasis_paratime_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_set-default()
{
    last_command="oasis_paratime_set-default"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_paratime_show()
{
    last_command="oasis_paratime_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--round=")
    two_word_flags+=("--round")
    local_nonpersistent_flags+=("--round")
    local_nonpersistent_flags+=("--round=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime_statistics()
{
    last_command="oasis_paratime_statistics"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_paratime()
{
    last_command="oasis_paratime"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("denomination")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("denom")
        aliashash["denom"]="denomination"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("register")
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("set-default")
    commands+=("show")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="show"
    fi
    commands+=("statistics")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("stats")
        aliashash["stats"]="statistics"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_build()
{
    last_command="oasis_rofl_build"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--no-container")
    local_nonpersistent_flags+=("--no-container")
    flags+=("--no-update-manifest")
    local_nonpersistent_flags+=("--no-update-manifest")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--only-validate")
    local_nonpersistent_flags+=("--only-validate")
    flags+=("--output=")
    two_word_flags+=("--output")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    local_nonpersistent_flags+=("-v")
    flags+=("--verify")
    local_nonpersistent_flags+=("--verify")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_create()
{
    last_command="oasis_rofl_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--no-update-manifest")
    local_nonpersistent_flags+=("--no-update-manifest")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--scheme=")
    two_word_flags+=("--scheme")
    local_nonpersistent_flags+=("--scheme")
    local_nonpersistent_flags+=("--scheme=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_deploy()
{
    last_command="oasis_rofl_deploy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--machine=")
    two_word_flags+=("--machine")
    local_nonpersistent_flags+=("--machine")
    local_nonpersistent_flags+=("--machine=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offer=")
    two_word_flags+=("--offer")
    local_nonpersistent_flags+=("--offer")
    local_nonpersistent_flags+=("--offer=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--provider=")
    two_word_flags+=("--provider")
    local_nonpersistent_flags+=("--provider")
    local_nonpersistent_flags+=("--provider=")
    flags+=("--replace-machine")
    local_nonpersistent_flags+=("--replace-machine")
    flags+=("--show-offers")
    local_nonpersistent_flags+=("--show-offers")
    flags+=("--term=")
    two_word_flags+=("--term")
    local_nonpersistent_flags+=("--term")
    local_nonpersistent_flags+=("--term=")
    flags+=("--term-count=")
    two_word_flags+=("--term-count")
    local_nonpersistent_flags+=("--term-count")
    local_nonpersistent_flags+=("--term-count=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--wipe-storage")
    local_nonpersistent_flags+=("--wipe-storage")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_identity()
{
    last_command="oasis_rofl_identity"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--component=")
    two_word_flags+=("--component")
    local_nonpersistent_flags+=("--component")
    local_nonpersistent_flags+=("--component=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_init()
{
    last_command="oasis_rofl_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--reset")
    local_nonpersistent_flags+=("--reset")
    flags+=("--tee=")
    two_word_flags+=("--tee")
    local_nonpersistent_flags+=("--tee")
    local_nonpersistent_flags+=("--tee=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_list()
{
    last_command="oasis_rofl_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_change-admin()
{
    last_command="oasis_rofl_machine_change-admin"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_logs()
{
    last_command="oasis_rofl_machine_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_remove()
{
    last_command="oasis_rofl_machine_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_restart()
{
    last_command="oasis_rofl_machine_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--wipe-storage")
    local_nonpersistent_flags+=("--wipe-storage")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_show()
{
    last_command="oasis_rofl_machine_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_stop()
{
    last_command="oasis_rofl_machine_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--wipe-storage")
    local_nonpersistent_flags+=("--wipe-storage")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine_top-up()
{
    last_command="oasis_rofl_machine_top-up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--term=")
    two_word_flags+=("--term")
    local_nonpersistent_flags+=("--term")
    local_nonpersistent_flags+=("--term=")
    flags+=("--term-count=")
    two_word_flags+=("--term-count")
    local_nonpersistent_flags+=("--term-count")
    local_nonpersistent_flags+=("--term-count=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_machine()
{
    last_command="oasis_rofl_machine"

    command_aliases=()

    commands=()
    commands+=("change-admin")
    commands+=("logs")
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("cancel")
        aliashash["cancel"]="remove"
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("restart")
    commands+=("show")
    commands+=("stop")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("terminate")
        aliashash["terminate"]="stop"
    fi
    commands+=("top-up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_create()
{
    last_command="oasis_rofl_provider_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_init()
{
    last_command="oasis_rofl_provider_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_list()
{
    last_command="oasis_rofl_provider_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--show-offers")
    local_nonpersistent_flags+=("--show-offers")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_remove()
{
    last_command="oasis_rofl_provider_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_show()
{
    last_command="oasis_rofl_provider_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_update()
{
    last_command="oasis_rofl_provider_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider_update-offers()
{
    last_command="oasis_rofl_provider_update-offers"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_provider()
{
    last_command="oasis_rofl_provider"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("init")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remove")
    commands+=("show")
    commands+=("update")
    commands+=("update-offers")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_push()
{
    last_command="oasis_rofl_push"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_remove()
{
    last_command="oasis_rofl_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_secret_get()
{
    last_command="oasis_rofl_secret_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_secret_import()
{
    last_command="oasis_rofl_secret_import"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_secret_rm()
{
    last_command="oasis_rofl_secret_rm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_secret_set()
{
    last_command="oasis_rofl_secret_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--public-name=")
    two_word_flags+=("--public-name")
    local_nonpersistent_flags+=("--public-name")
    local_nonpersistent_flags+=("--public-name=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_secret()
{
    last_command="oasis_rofl_secret"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("import")
    commands+=("rm")
    commands+=("set")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_show()
{
    last_command="oasis_rofl_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_trust-root()
{
    last_command="oasis_rofl_trust-root"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--height=")
    two_word_flags+=("--height")
    local_nonpersistent_flags+=("--height")
    local_nonpersistent_flags+=("--height=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_update()
{
    last_command="oasis_rofl_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment")
    local_nonpersistent_flags+=("--deployment=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl_upgrade()
{
    last_command="oasis_rofl_upgrade"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_rofl()
{
    last_command="oasis_rofl"

    command_aliases=()

    commands=()
    commands+=("build")
    commands+=("create")
    commands+=("deploy")
    commands+=("identity")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("id")
        aliashash["id"]="identity"
    fi
    commands+=("init")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("machine")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("i")
        aliashash["i"]="machine"
    fi
    commands+=("provider")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("p")
        aliashash["p"]="provider"
    fi
    commands+=("push")
    commands+=("remove")
    commands+=("secret")
    commands+=("show")
    commands+=("trust-root")
    commands+=("update")
    commands+=("upgrade")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_transaction_show()
{
    last_command="oasis_transaction_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_transaction_sign()
{
    last_command="oasis_transaction_sign"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--encrypted")
    local_nonpersistent_flags+=("--encrypted")
    flags+=("--fee-denom=")
    two_word_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom")
    local_nonpersistent_flags+=("--fee-denom=")
    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--gas-limit=")
    two_word_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit")
    local_nonpersistent_flags+=("--gas-limit=")
    flags+=("--gas-price=")
    two_word_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price")
    local_nonpersistent_flags+=("--gas-price=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--nonce=")
    two_word_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce")
    local_nonpersistent_flags+=("--nonce=")
    flags+=("--offline")
    local_nonpersistent_flags+=("--offline")
    flags+=("--output-file=")
    two_word_flags+=("--output-file")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output-file")
    local_nonpersistent_flags+=("--output-file=")
    local_nonpersistent_flags+=("-o")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--unsigned")
    local_nonpersistent_flags+=("--unsigned")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_transaction_submit()
{
    last_command="oasis_transaction_submit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--account=")
    two_word_flags+=("--account")
    flags_with_completion+=("--account")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--account")
    local_nonpersistent_flags+=("--account=")
    flags+=("--network=")
    two_word_flags+=("--network")
    flags_with_completion+=("--network")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--no-paratime")
    local_nonpersistent_flags+=("--no-paratime")
    flags+=("--paratime=")
    two_word_flags+=("--paratime")
    flags_with_completion+=("--paratime")
    flags_completion+=("__oasis_handle_go_custom_completion")
    local_nonpersistent_flags+=("--paratime")
    local_nonpersistent_flags+=("--paratime=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_transaction()
{
    last_command="oasis_transaction"

    command_aliases=()

    commands=()
    commands+=("show")
    commands+=("sign")
    commands+=("submit")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_update()
{
    last_command="oasis_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_create()
{
    last_command="oasis_wallet_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file.algorithm=")
    two_word_flags+=("--file.algorithm")
    local_nonpersistent_flags+=("--file.algorithm")
    local_nonpersistent_flags+=("--file.algorithm=")
    flags+=("--file.number=")
    two_word_flags+=("--file.number")
    local_nonpersistent_flags+=("--file.number")
    local_nonpersistent_flags+=("--file.number=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--ledger.algorithm=")
    two_word_flags+=("--ledger.algorithm")
    local_nonpersistent_flags+=("--ledger.algorithm")
    local_nonpersistent_flags+=("--ledger.algorithm=")
    flags+=("--ledger.number=")
    two_word_flags+=("--ledger.number")
    local_nonpersistent_flags+=("--ledger.number")
    local_nonpersistent_flags+=("--ledger.number=")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_export()
{
    last_command="oasis_wallet_export"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_wallet_import()
{
    last_command="oasis_wallet_import"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--algorithm=")
    two_word_flags+=("--algorithm")
    local_nonpersistent_flags+=("--algorithm")
    local_nonpersistent_flags+=("--algorithm=")
    flags+=("--number=")
    two_word_flags+=("--number")
    local_nonpersistent_flags+=("--number")
    local_nonpersistent_flags+=("--number=")
    flags+=("--secret=")
    two_word_flags+=("--secret")
    local_nonpersistent_flags+=("--secret")
    local_nonpersistent_flags+=("--secret=")
    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_import-file()
{
    last_command="oasis_wallet_import-file"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_list()
{
    last_command="oasis_wallet_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_remote-signer()
{
    last_command="oasis_wallet_remote-signer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_wallet_remove()
{
    last_command="oasis_wallet_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_wallet_rename()
{
    last_command="oasis_wallet_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_wallet_set-default()
{
    last_command="oasis_wallet_set-default"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_wallet_show()
{
    last_command="oasis_wallet_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--yes")
    flags+=("-y")
    local_nonpersistent_flags+=("--yes")
    local_nonpersistent_flags+=("-y")
    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_oasis_wallet()
{
    last_command="oasis_wallet"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("export")
    commands+=("import")
    commands+=("import-file")
    commands+=("list")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("remote-signer")
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rm")
        aliashash["rm"]="remove"
    fi
    commands+=("rename")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("mv")
        aliashash["mv"]="rename"
    fi
    commands+=("set-default")
    commands+=("show")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("s")
        aliashash["s"]="show"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_oasis_root_command()
{
    last_command="oasis"

    command_aliases=()

    commands=()
    commands+=("account")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("a")
        aliashash["a"]="account"
        command_aliases+=("acc")
        aliashash["acc"]="account"
        command_aliases+=("accounts")
        aliashash["accounts"]="account"
    fi
    commands+=("addressbook")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ab")
        aliashash["ab"]="addressbook"
    fi
    commands+=("completion")
    commands+=("contract")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("c")
        aliashash["c"]="contract"
        command_aliases+=("contracts")
        aliashash["contracts"]="contract"
    fi
    commands+=("help")
    commands+=("network")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("n")
        aliashash["n"]="network"
        command_aliases+=("net")
        aliashash["net"]="network"
    fi
    commands+=("paratime")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("p")
        aliashash["p"]="paratime"
        command_aliases+=("pt")
        aliashash["pt"]="paratime"
    fi
    commands+=("rofl")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("r")
        aliashash["r"]="rofl"
    fi
    commands+=("transaction")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("tx")
        aliashash["tx"]="transaction"
    fi
    commands+=("update")
    commands+=("wallet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("w")
        aliashash["w"]="wallet"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_oasis()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __oasis_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("oasis")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __oasis_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_oasis oasis
else
    complete -o default -o nospace -F __start_oasis oasis
fi

# ex: ts=4 sw=4 et filetype=sh
