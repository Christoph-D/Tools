#!/bin/bash
#
# Records audio from alsa.
#
# Usage:
# Bind some hotkey to "$this_script toggle", then run this script
# without parameters from the command line. Whenever you press the
# assigned hotkey, an audio clip will be recorded.

set -e -u -m

capture_dir=${capture_dir-$HOME/audio_clips}
lock_file="$capture_dir/.audio_capture.lock"
event_file="$capture_dir/.audio_capture.event"

mkdir -p "$capture_dir"

next_file() { (
    cd "$capture_dir"
    for file in "$1"???".$2"; do last=$file; done
    if [[ $last = "$1???$2" ]]; then
        printf "%s000.%s" "$1" "$2"
    else
        printf "%s%03d.%s" "$1" \
            $(( 1 + $(echo "$last" | sed "s/$1\([0-9]*\)\.$2/\1/;s/^0*\(.\)/\1/") )) "$2"
    fi
) }

trap 'kill %1 &>/dev/null' EXIT

watch_mode() { (
    if ! flock --nonblock 200; then
        echo "Running multiple instances is not supported." >&2
        exit 0
    fi
    local capturing=
    while : >"$event_file" && inotifywait -qqe MODIFY "$event_file"; do
        local event
        event=$(cat "$event_file")
        if [[ $event = toggle ]]; then
            if [[ ! $capturing ]]; then
                capturing=1
                echo -n "Capturing audio..."
                target="$capture_dir/$(next_file clip ogg)"
                arecord -q -f cd -t wav | oggenc -Q -o "$target" - &>/dev/null &
            else
                capturing=
                kill %1 &>/dev/null
                wait &>/dev/null
                echo "saved $target"
            fi
        else
            echo "Unknown event: $event"
        fi
    done
) 200>"$lock_file"; }

if [[ $# -eq 0 ]]; then
    watch_mode
elif [[ $# -eq 1 && $1 = toggle ]]; then
    echo toggle >"$event_file"
else
    echo "Usage: $(basename "$0") [toggle]"
fi

exit 0
