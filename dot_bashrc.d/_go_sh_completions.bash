_go_sh_completions() {
    local script curr prev
    script=${1:?need script}
    curr=${2?need current word}
    prev=${3?need previous word}

#     >&2 printf $'\n\n'
#     >&2 printf $'script=:%q:\n' "${script:-empty${script- and unset}}"
#     >&2 printf $'curr=:%q:\n' "${curr:-empty${curr- and unset}}"
#     >&2 printf $'prev=:%q:\n' "${prev:-empty${prev- and unset}}"

    if [ "${prev?}" = "${script:?}" ]; then
        prev=
    fi

    local IFS

    local functions
    functions=()

    exec <"${script:?}"
    while IFS= read -r -d $'\n' line; do
        if re='^(go-[-[:alnum:]]+)\(\)'; [[ $line =~ $re ]]; then
            functions+=( "${BASH_REMATCH[1]:?}" )
        fi
    done
    exec <&-

    prefixes=()
    
    # First, completions for functions that include the previous function name
    # and the current partial completion.
    #
    # e.g. curr="ex" prev="docker" we need to find all functions that include
    # "-docker-ex"
    if [ -n "${prev:+isset}" ] && [ -n "${curr:+isset}" ]; then
        prefixes+=( "-${prev:?}-${curr:?}" )
    fi

    # Next, completions for functions that only include the previous function
    # name.
    #
    # e.g. curr="" prev="docker" we need to find all functions that include
    # "-docker-"
    if [ -n "${prev:+isset}" ] && [ -z "${curr:+isset}" ]; then
        prefixes+=( "-${prev:?}-" )
    fi

    # Finally, any top-level functions
    prefixes+=( "go-" )

    words=()
    for prefix in "${prefixes[@]}"; do
#         >&2 printf $'prefix=:%q:\n' "${prefix?}"
        for function in "${functions[@]/}"; do
            if [[ ${function:?} == *${prefix?}* ]]; then
#                 >&2 printf $'prefix=:%q:\n' "${prefix?}"
#                 >&2 printf $'function=:%q:\n' "${function?}"

                # We need to get just the next word here.
                #
                # e.g. prefix="-docker-ex" function="go-docker-exec"

                # If the prefix ends with a lone "-", remove it.
                #
                # e.g. prefix="-docker-" -> word="-docker"
                word=${prefix%-}

                # Remove any partial completion
                #
                # e.g. word="-docker-ex" -> word="-docker"

                word=${word%-*}
#                 >&2 printf $'word=:%q:\n' "${word}"

                # Remove our prefix from the function
                #
                # e.g. function="go-docker-exec" word="-docker" -> word="exec"

                word=${function##*${word}-}
#                 >&2 printf $'word=:%q:\n' "${word}"

#                 >&2 printf $':%q:\n' "${word:?}"

                # If the only completion is the previous word the user typed,
                # just ignore it.
                #
                # e.g. curr="" prev="docker" word="docker" -> ignore

                if [ "${word?}" = "${prev}" ]; then
                    continue
                fi

                # Split the word into pieces.
                #
                # e.g. word="exec-foo-bar" -> words+=( "exec" "foo" "bar" )

                IFS='-'
                words+=( ${word} )
            fi
        done
    done

    # This is the simplest possible completion function. It simply finds all
    # possible words by splitting each function e.g. "go-foo-bar-baz" into
    # words "foo" "bar" "baz" and then offers them for autocompletion.
    #
    # This alone is enough of a completion but doesn't take into context
    # previous/wrapper commands. We add it here as a catch-all.

    words=()
    for function in "${functions[@]/#go-/}"; do
        IFS='-'
        words+=( ${function} )
    done

    # Finally, we actually run the completion.

    IFS=' '
    words="${words[*]}"
#     >&2 printf $':%q:\n' "${words:?}"
    compgen -W "${words:?}" "${curr?}"
#     COMPREPLY=( $(compgen -W "${words:?}" "${curr?}") )
}

# if ! (return 0 &>/dev/null); then
#     if [ $# -eq 0 ]; then
#         set -- "./go.sh" "" "docker"
#     fi
# 
#     _go_sh_completions "$@"
# else
#     complete -C _go_sh_completions ./go.sh
# fi
