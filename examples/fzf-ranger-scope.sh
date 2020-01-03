#!/usr/bin/env bash


function create_preview {
    local path="$(realpath "$1")"
    local path_sha1="$(<<<"$path" sha1sum -)"
    local cache_image_path="$HOME/.cache/ranger/${path_sha1%% *-}.jpg"
    local text_preview=
    
    # Wrong exit code if declared (local) & assigned at once..
    # https://github.com/ranger/ranger/blob/3f8e7c14103a6570b0e55fbcf84242c86f42a7cb/ranger/core/actions.py#L1187
    text_preview="$("$HOME/.config/ranger/scope.sh" \
        "$path" "$COLUMNS" "$LINES" \
        "$cache_image_path" \
        True)"

    ## Meanings of exit codes:
    case "$?" in
        ## code | meaning    | action of ranger
        ## -----+------------+-------------------------------------------
        ## 0    | success    | Display stdout as preview
        ## 3    | fix width  | Don't reload when width changes
        ## 4    | fix height | Don't reload when height changes
        ## 5    | fix both   | Don't ever reload
        0|3|4|5)
            CLEAR_PREVIEW
            echo "$text_preview"
            ;;
        ## 1    | no preview | Display no preview at all
        1)
            CLEAR_PREVIEW
            ;;
        ## 2    | plain text | Display the plain content of the file
        2)
            CLEAR_PREVIEW
            cat "$path"
            ;;
        ## 6    | image      | Display the image `$IMAGE_CACHE_PATH` points to as an image preview
        6)
            DRAW_PREVIEW "$cache_image_path"
            ;;
        ## 7    | image      | Display the file directly as an image
        7)
            DRAW_PREVIEW "$path"
            ;;
    esac
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    export -f create_preview
    exec fzf-ueberzogen.sh --preview 'create_preview {}' "$@"
fi
