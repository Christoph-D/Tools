#!/bin/bash

download_mms() {
    if [[ ! -f $2 ]]; then
        echo "Downloading $1 to $2"
        # Now I would like to do something like this:
        # { mimms "$1" "$2" > /dev/null ; echo "Done with $2"; } &
        # Then the EXIT trap does not catch all of the mimms
        # processes, though, so we can't do that.
        # TODO: Figure out how to make this work.
        mimms "$1" "$2" > /dev/null &
    else
        echo "NOT downloading $1 to $2 because the file exists!"
    fi
}

get_file_path() {
    read -d '\t' -r topic number title section < \
        <(printf '%s\n' "$1" | sed 's/.*| \([^|]\+\) | 第\([0-9]\+\)回 \([^ ]*\) \(.*\)$/\1\t\2\t\4\t\3/')
    path="$topic"
    mkdir -p "$path"
    printf '%s/%02d - %s (%s).wmv' "$path" "$number" "$title" "$section"
}

download_topic() {
    base="${1}archive/"
    for (( i=1; i < 100; ++i )); do
        chapter=$(curl -s "${base}chapter$(printf '%03d' "$i").html" | iconv -c -f sjis -t utf8 | fromdos)
        title=$(printf '%s\n' "${chapter}" | sed 's#^<title>\(.*\)</title>$#\1#;t;d')
        media=$(printf '%s\n' "${chapter}" | \
            sed 's#^\t<noscript><a href="\(http://www.nhk.or.jp/kokokoza/metafiles/.*\.asx\)" target="_blank">.*$#\1#;t;d')
        [[ $title && $media ]] || return 0
        mms=$(curl -s "$media" | sed 's#^.*"\(mms://.*\)".*$#\1#;t;d')
        download_mms "$mms" "$(get_file_path "$title")"
    done
}

# Kill jobs on exit
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

if [[ $# -eq 1 && $1 =~ ^http.* ]]; then
    download_topic "$1"
    echo "Downloads started. Please wait."
    wait
    exit 0
elif [[ $# -gt 0 ]]; then
    echo 'Usage:'
    echo 'nhk_download.sh [topic-url]'
    echo 'Topic URLs are the links of the colored buttons on'
    echo 'http://www.nhk.or.jp/kokokoza/library/index.html'
    exit 0
fi

while read -r topic; do
    echo "Starting download of topic $topic"
    download_topic "http://www.nhk.or.jp/kokokoza/library/$topic"
    echo "Downloads started. Please wait."
    wait
done < <(curl -s 'http://www.nhk.or.jp/kokokoza/library/index.html' | iconv -c -f sjis -t utf8 | fromdos | \
    sed 's#<div class="lby_txt"><a href="\(2010/tv/[^"]\+\)" onMouseOver=".*$#\1#;t;d')

exit 0
