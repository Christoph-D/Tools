#!/bin/bash

escape_for_grep() {
    local a=${1//\\/\\\\}
    a=${a//./\\.}
    a=${a//\*/\\*}
    a=${a//\$/\\\$}
    a=${a//\^/\\^}
    a=${a//[/\\[}
    a=${a//]/\\]}
    printf '%s\n' "$a"
}

find_files() {
    find "${1-.}" -maxdepth 1 -type f "${minsize[@]}" "${maxsize[@]}" ! -name '.md5*'
}

contains_files() {
    [[ -n $(find_files "$1") ]]
}

check_for_missing_files() {
    [[ -f .md5 ]] || return 0
    while read -r hash filename; do
        if [[ ! -f "${filename#\*}" ]]; then
            printf 'Missing file: %s\n' "$(pwd)/${filename#\*}"
            if [[ ! $readonly ]]; then
                if [[ $removemissing ]]; then
                    answer=y
                else
                    read -p '** Remove the old checksum? [Yn]' answer <&10
                fi
                if [[ ! $answer || $answer = y || $answer = Y ]]; then
                    grep -v " $(escape_for_grep "$filename")$" .md5 > .md5_tmp
                    mv .md5_tmp .md5
                else
                    exit 1
                fi
            else
                read -p '** Abort? [Yn]' answer <&10
                if [[ ! $answer || $answer = y || $answer = Y ]]; then
                    exit 1
                fi
            fi
        fi
    done 10<&1 < .md5
    # Remove empty checksum file
    [[ -s .md5 || ! $readonly ]] || rm .md5
}

create_checksum() {
    md5deep -ekbf <(find_files) > .md5
}

check_and_update_checksum() { (
    cd "$1" || exit 1
    check_for_missing_files

    if [[ ! -s .md5 ]]; then
        [[ ! $readonly ]] || exit 0
        echo '** Empty or no checksum file. Generating new checksums...'
        create_checksum
        exit
    fi

    md5deep -ekbX .md5 -f <(find_files) > "$tmpfile"
    [[ -s "$tmpfile" ]] || exit 0
    while read -r hash filename; do
        if ! grep -q " $(escape_for_grep "$filename")$" .md5; then
            if [[ ! $readonly ]]; then
                printf 'Adding missing checksum for: %s\n' "$(pwd)/${filename#\*}"
                printf '%s %s\n' "$hash" "$filename" >> .md5
            else
                printf 'Missing checksum for: %s\n' "$(pwd)/${filename#\*}"
                read -p '** Abort? [yN]' answer <&10
                if [[ $answer = y || $answer = Y ]]; then
                    exit 1
                fi
            fi
        else
            printf 'Checksum differs for: %s\n' "$(pwd)/${filename#\*}"
            printf 'New checksum: %s\n' "$hash"
            if [[ ! $readonly ]]; then
                read -p '** Use the new checksum? [Yn]' answer <&10
                if [[ ! $answer || $answer = y || $answer = Y ]]; then
                    grep -v " $(escape_for_grep "$filename")$" .md5 > .md5_tmp
                    printf '%s %s\n' "$hash" "$filename" >> .md5_tmp
                    mv .md5_tmp .md5
                else
                    exit 1
                fi
            else
                read -p '** Abort? [yN]' answer <&10
                if [[ $answer = y || $answer = Y ]]; then
                    exit 1
                fi
            fi
        fi
    done 10<&1 < "$tmpfile"
) }

base=${1-.}
minsize=()
maxsize=()
readonly=
removemissing=
while [[ $# -gt 0 ]]; do
    if [[ $base = --min-size ]]; then
        minsize=( -size +"$2" )
        shift 2
        base=${1-.}
    elif [[ $base = --max-size ]]; then
        maxsize=( -size -"$2" )
        shift 2
        base=${1-.}
    elif [[ $base = --read-only ]]; then
        shift
        base=${1-.}
        readonly=1
    elif [[ $base = --remove-missing ]]; then
        shift
        base=${1-.}
        removemissing=1
    else
        shift
        break
    fi
done

if [[ ! -d $base || $# -ne 0 ]]; then
    echo "Usage: $(basename "$0") [--min-size <size>] [--max-size <size>] [--read-only] [--remove-missing] [directory]"
    echo '
Verifies and updates checksum files recursively starting from the
given directory. If no directory is given, start from the current
directory.

With --min-size/--max-size all files smaller/larger than the given
size are ignored.  Existing checksums of files not meeting the size
criteria will not be removed even if --remove-missing is specified.

With --read-only no checksum files will be generated or modified.

With --remove-missing checksums for missing files are removed without
asking.'
    exit 0
fi

printf '** Will verify all checksums starting from %s\n' "$base"
if [[ $readonly ]]; then
    echo '** Missing or wrong checksums will *not* be generated or fixed.'
    echo '** This is the read-only mode.'
else
    echo '** Missing checksums will be generated automatically.'
fi
read -p '** Proceed? [Yn]' answer
[[ ! $answer || $answer = y || $answer = Y ]] || exit 1

tmpfile=$(mktemp)

while IFS= read -d '' -r dir; do
    contains_files "$dir" || continue
    echo -e "\n** Checking $dir"
    if ! check_and_update_checksum "$dir"; then
        echo "** Checksum error in $dir"
        rm "$tmpfile"
        exit 1
    fi
done < <(find "$base" -type d -print0)

rm "$tmpfile"
exit 0
