#!/bin/bash
# Probably broken

if [[ $# -lt 3 ]]; then
    echo "Usage: $(basename "$0") <out.mp4> <width:height> <program...>"
    echo "Captures OpenGL output."
    exit 0
fi

RESULT=$1
if ! rm -f "$RESULT" && touch "$RESULT"; then
    echo "Error: Cannot write to $RESULT"
    exit 1
fi
WIDTH_HEIGHT=$2
shift 2

TMP_DIR=$(mktemp -d)

cd "$TMP_DIR" || exit 1
# shellcheck disable=SC2064
trap "rm -rf '$TMP_DIR'" EXIT

declare -a PIDS

echo 'Setting up fifo chain...'
mkfifo capture audio_source video_source video.y4m

#glc-capture --start -o >( \
#    glc-play <(cat) -v 10 -y 1 -o - | \
#    mplayer - &>/dev/null \
#    ) --disable-audio "$@" &> /dev/null
#exit 1

# Duplicate the stream.
#tee video_source >audio_source <capture &
#(while :; do cat capture >video_source; done) &>/dev/null &
#PIDS=( ${PIDS[@]} $! )

glc-play ./capture -y 1 -o - | \
    mplayer -vo yuv4mpeg:file=./video.y4m -vf scale="$WIDTH_HEIGHT" -nosound -benchmark - &>/dev/null &
PIDS=( "${PIDS[@]}" $! )

#cat audio_source > /dev/null &
#PIDS=( "${PIDS[@]}" $! )

#glc-play ./audio_source -a 1 -o - | \
#    mplayer - &
#oggenc --output=/tmp/audio.ogg - &
#PIDS=( "${PIDS[@]}" $! )

/usr/bin/x264 --tune animation --preset medium --crf 28 --threads auto \
    --output ./r.mp4 ./video.y4m &>/dev/null &
PIDS=( "${PIDS[@]}" $! )

echo 'Launching program...'

clean_up() {
    echo "Cleaning up..."
    rm -rf "$TMP_DIR"
    exec &>/dev/null
    for P in "${PIDS[@]}"; do kill "$P" &>/dev/null; done
    sleep 0.1
    for P in "${PIDS[@]}"; do kill -9 "$P" &>/dev/null; done
}
trap clean_up EXIT

glc-capture --start -o ./capture --disable-audio "$@" &> /dev/null
echo 'Waiting for processes to terminate...'
wait
# shellcheck disable=SC2064
trap "rm -rf '$TMP_DIR'" EXIT

rm -f "$RESULT"
MP4Box -add r.mp4 "$RESULT" &>/dev/null
echo "Done. Result: $RESULT ($(du -sh "$RESULT" | cut -f 1))"

exit 0
