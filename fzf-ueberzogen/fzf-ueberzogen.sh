#!/usr/bin/env bash
# fzf-ueberzogen.sh is a wrapper script which allows to use ueberzug with fzf.
# Copyright (C) 2019  Nico Baeurer

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
readonly BASH_BINARY="$(which bash)"
readonly REDRAW_COMMAND="toggle-preview+toggle-preview"
readonly REDRAW_KEY="µ"
declare -r -x DEFAULT_PREVIEW_POSITION="right"
declare -r -x UEBERZUG_FIFO="$(mktemp --dry-run --suffix "fzf-$$-ueberzug")"
declare -r -x PREVIEW_ID="preview"


function STORE_TERMINAL_SIZE_IN {
    # Usage: STORE_TERMINAL_SIZE_IN 
    #           lines_variable columns_variable
    [[ ! -v "$1" || ! -v "$2" ]] && return 1
    < <(</dev/tty stty size) \
        read "$1" "$2"
}


function STORE_FZF_HEIGHT_IN {
    # Usage: STORE_FZF_HEIGHT_IN
    #           fzf_height_lines_variable
    #           terminal_lines fzf_height fzf_min_height
    [[ $# -ne 4 || ! -v "$1" ]] && return 1
    local -n _fzf_height_lines="$1"
    local terminal_lines="$2"
    local fzf_height_text="$3"
    local fzf_min_height="$4"

    _fzf_height_lines="${fzf_height_text}"

    if [[ "${fzf_height_text}" == *"%" ]]; then
        ((_fzf_height_lines=(terminal_lines * ${fzf_height_text%\%}) / 100))
    else
        ((_fzf_height_lines=_fzf_height_lines > terminal_lines ? terminal_lines :_fzf_height_lines))
    fi

    ((_fzf_height_lines=fzf_min_height > _fzf_height_lines
                        ? fzf_min_height : _fzf_height_lines))
}


function STORE_FZF_OFFSET_IN {
    # Usage: STORE_FZF_OFFSET_IN
    #           fzf_offset_y_variable
    #           terminal_lines fzf_height fzf_start_offset_y
    [[ $# -ne 4 || ! -v "$1" ]] && return 1
    local -n _fzf_offset_y="$1"
    local terminal_lines="$2"
    local fzf_height="$3"
    local fzf_start_offset_y="$4"

    # Two cases:
    # 1. There isn't enough space, so fzf will print blank lines.
    #    -> OFFSET_Y = terminal height - required lines
    # 2. There is enough space -> OFFSET_Y = START_OFFSET_Y
    ((_fzf_offset_y=terminal_lines - fzf_height))
    ((_fzf_offset_y=_fzf_offset_y < fzf_start_offset_y
                    ? _fzf_offset_y : fzf_start_offset_y))
}


function STORE_PREVIEW_POSITION_IN {
    # Usage: STORE_PREVIEW_POSITION_IN
    #           preview_y_variable preview_x_variable
    #           preview_position fzf_offset_y fzf_height
    #           terminal_width preview_height preview_width
    [[ $# -ne 8 || ! -v "$1" || ! -v "$2" ]] && return 1
    local -n _preview_y="$1"
    local -n _preview_x="$2"
    local preview_position="$3"
    local fzf_offset_y="$4"
    local fzf_height="$5"
    local terminal_width="$6"
    local preview_height="$7"
    local preview_width="$8"

    case "${preview_position}" in
        left|up|top)
            _preview_x=2
            _preview_y=$((1 + fzf_offset_y))
            ;;
        right)
            _preview_x=$((terminal_width - preview_width - 2))
            _preview_y=$((1 + fzf_offset_y))
            ;;
        down|bottom)
            _preview_x=2
            _preview_y=$((fzf_offset_y + fzf_height - preview_height - 1))
            ;;
    esac
}


function DRAW_PREVIEW {
    # Usage: DRAW_PREVIEW path
    local -A add_preview_command=( \
        [identifier]="${PREVIEW_ID}" \
        [scaler]=cover [scaling_position_x]=0.5 [scaling_position_y]=0.5 \
        [path]="${@}")
    ADD_PLACEMENT add_preview_command
}


function CLEAR_PREVIEW {
    # Usage: CLEAR_PREVIEW
    REMOVE_PLACEMENT "${PREVIEW_ID}"
}


function IDENTITY_RECT {
    # Usage: IDENTITY_RECT
    #           placement_rect_variable
    [[ $# -ne 1 ]] && return 1
}


function ADD_PLACEMENT {
    # Usage: ADD_PLACEMENT
    #           add_command_variable [adjust_rect_function]
    # references can't be checked.. -v doesn't seem to support associative arrays..
    local terminal_lines= terminal_columns=
    local fzf_height= fzf_offset_y=
    local preview_y= preview_x=
    local preview_height="${LINES}" preview_width="${COLUMNS}"
    STORE_TERMINAL_SIZE_IN \
        terminal_lines terminal_columns
    STORE_FZF_HEIGHT_IN \
        fzf_height \
        "$terminal_lines" "${FZF_HEIGHT}" "${FZF_MIN_HEIGHT}"
    STORE_FZF_OFFSET_IN \
        fzf_offset_y \
        "$terminal_lines" "${fzf_height}" "${FZF_START_OFFSET_Y}"
    STORE_PREVIEW_POSITION_IN \
        preview_y preview_x \
        "${PREVIEW_POSITION:-${DEFAULT_PREVIEW_POSITION}}" \
        "${fzf_offset_y}" "${fzf_height}" "${terminal_columns}" \
        "${preview_height}" "${preview_width}"

    local _add_command_nameref="$1"
    local -n _add_command="${_add_command_nameref}"
    local adjust_rect_callback="${2:-IDENTITY_RECT}"
    local -A adjusted_placement_rect=( \
        [y]="${preview_y}" [x]="${preview_x}" \
        [height]="${preview_height}" [width]="${preview_width}")
    "${adjust_rect_callback}" adjusted_placement_rect
    _add_command[action]=add
    _add_command[x]="${adjusted_placement_rect[x]}"
    _add_command[y]="${adjusted_placement_rect[y]}"
    _add_command[width]="${adjusted_placement_rect[width]}"
    _add_command[height]="${adjusted_placement_rect[height]}"

    >"${UEBERZUG_FIFO}" \
        declare -p "${_add_command_nameref}"
}


function REMOVE_PLACEMENT {
    # Usage: REMOVE_PLACEMENT placement-id
    [[ $# -ne 1 ]] && return 1
    >"${UEBERZUG_FIFO}" \
        declare -A -p _remove_command=( \
        [action]=remove [identifier]="${1}")
}


function is_option_key [[ "${@}" =~ ^(\-.*|\+.*) ]]
function is_key_value [[ "${@}" == *=* ]]


function store_options_map_in {
    # Usage: store_options_map_in
    #           options_map_variable options_variable
    # references can't be checked.. -v doesn't seem to support associative arrays..
    [[ $# -ne 2 || ! -v "$2" ]] && return 1
    local -n _options_map="${1}"
    local -n _options="${2}"

    for ((i=0; i < ${#_options[@]}; i++)); do
        local key="${_options[$i]}" next_key="${_options[$((i + 1))]:---}"
        local value=true
        is_option_key "${key}" || \
            continue
        if is_key_value "${key}"; then
            <<<"${key}" \
                IFS='=' read key value
        elif ! is_option_key "${next_key}"; then
            value="${next_key}"
        fi
        _options_map["${key}"]="${value}"
    done
}


function process_options {
    # Usage: process_options command-line-arguments
    local -a "default_options=(${FZF_DEFAULT_OPTS})"
    local -a script_options=("${@}")
    local -A mapped_options
    store_options_map_in mapped_options default_options
    store_options_map_in mapped_options script_options 

    local cursor_y= cursor_x=
    store_cursor_position_in cursor_y cursor_x
    # If fzf is used as completion tool we will get the position of the prompt.
    # If it's normally used we get the position the output will be displayed at.
    # If it's normally used we need to subtract one to get the position of the prompt.
    ((cursor_y=cursor_x != 1 ? cursor_y : cursor_y - 1))
    declare -g -r -x FZF_START_OFFSET_Y="${cursor_y}"
    declare -g -r -x PREVIEW_POSITION="${mapped_options[--preview-window]%%:[^:]*}"
    declare -g -r -x FZF_HEIGHT="${mapped_options[--height]:-100%}"
    declare -g -r -x FZF_MIN_HEIGHT="${mapped_options[--min-height]:-10}"
}


function store_cursor_position_in {
    # Usage: store_cursor_pos_in
    #           y_variable x_variable
    # based on https://github.com/dylanaraps/pure-bash-bible#get-the-current-cursor-position
    [[ ! -v "$1" || ! -v "$2" ]] && return 1
    </dev/tty &>/dev/tty \
        IFS='[;' \
        read -p $'\e[6n' -d R -rs _ "${1}" "${2}" _
}


function start_ueberzug {
    # Usage: start_ueberzug
    mkfifo "${UEBERZUG_FIFO}"
    <"${UEBERZUG_FIFO}" \
        ueberzug layer --parser bash --silent &
    # prevent EOF
    3>"${UEBERZUG_FIFO}" \
        exec
}


function finalise {
    # Usage: finalise
    3>&- \
        exec
    &>/dev/null \
        rm "${UEBERZUG_FIFO}"
    &>/dev/null \
        kill $(jobs -p)
}


function print_on_winch {
    # Usage: print_on_winch text
    # print "$@" to stdin on receiving SIGWINCH
    # use exec as we will only kill direct childs on exiting,
    # also the additional bash process isn't needed
    </dev/tty \
        exec perl -e '
            require "sys/ioctl.ph";
            while (1) {
                local $SIG{WINCH} = sub {
                    ioctl(STDIN, &TIOCSTI, $_) for split "", join " ", @ARGV;
                };
                sleep;
            }' \
            "${@}" &
}


function export_functions {
    # Usage: export_functions
    # Exports all functions with a name
    # which only consists of underscores,
    # figures, upper case charactars
    local -a function_names="( $(compgen -A function) )"

    for function_name in "${function_names[@]}"; do
        [[ "${function_name}" =~ ^[A-Z0-9_]+$ ]] && {
            export -f "${function_name}"
        }
    done
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap finalise EXIT
    process_options "${@}"
    # print the redraw key twice as there's a run condition we can't circumvent
    # (we can't know the time fzf finished redrawing it's layout)
    print_on_winch "${REDRAW_KEY}${REDRAW_KEY}"
    start_ueberzug

    export_functions
    SHELL="${BASH_BINARY}" \
        fzf --preview "DRAW_PREVIEW {}" \
            --preview-window "${DEFAULT_PREVIEW_POSITION}" \
            --bind "${REDRAW_KEY}:${REDRAW_COMMAND}" \
            "${@}"
fi
