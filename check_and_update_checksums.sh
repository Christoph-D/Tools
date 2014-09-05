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

check_checksum() { (
    cd "$1" || exit 1
    # Check for missing files.
    while read -r hash filename; do
        if [[ ! -f "${filename#\*}" ]]; then
            printf 'Missing file: %s\n' "$(pwd)/${filename#\*}"
            if [[ ! $nogenerate ]]; then
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

    md5deep -ekbX .md5 -f <(find_files) > "$tmpfile"
    [[ -s "$tmpfile" ]] || exit 0
    while read -r hash filename; do
        if [[ ! $nogenerate ]] && ! grep -q " $(escape_for_grep "$filename")$" .md5; then
            printf 'Adding missing checksum for: %s\n' "$(pwd)/${filename#\*}"
            printf '%s %s\n' "$hash" "$filename" >> .md5
        else
            printf 'Checksum differs for: %s\n' "$(pwd)/${filename#\*}"
            printf 'New checksum: %s\n' "$hash"
            if [[ ! $nogenerate ]]; then
                read -p '** Use the new checksum? [Yn]' answer <&10
                if [[ ! $answer || $answer = y || $answer = Y ]]; then
                    grep -v " $(escape_for_grep "$filename")$" .md5 > .md5_tmp
                    printf '%s %s\n' "$hash" "$filename" >> .md5_tmp
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
    done 10<&1 < "$tmpfile"
) }

create_checksum() { (
    cd "$1" || exit 1
    md5deep -ekbf <(find_files) > .md5
) }

base=${1-.}
minsize=()
maxsize=()
nogenerate=
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
    elif [[ $base = --nogenerate ]]; then
        shift
        base=${1-.}
        nogenerate=1
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
    echo "Usage: $(basename "$0") [--min-size <size>] [--max-size <size>] [--nogenerate] [--remove-missing] [directory]"
    echo '
Verifies and updates checksum files recursively starting from the
given directory. If no directory is given, start from the current
directory.

With --min-size/--max-size all files smaller/larger than the given
size are ignored.  Existing checksums of files not meeting the size
criteria will be removed if --remove-missing is specified.

With --nogenerate no checksum files will be generated or modified.
This is the read-only mode.

With --remove-missing checksums for missing files are removed without
asking.'
    exit 0
fi

printf '** Will verify all checksums starting from %s\n' "$base"
if [[ $nogenerate ]]; then
    echo '** Missing or wrong checksums will *not* be generated or fixed.'
    echo '** This is the read-only mode. Directories containing no checksum file will not be mentioned at all.'
else
    echo '** Missing checksums will be generated automatically.'
fi
read -p '** Proceed? [Yn]' answer
[[ ! $answer || $answer = y || $answer = Y ]] || exit 1

tmpfile=$(mktemp)

while IFS= read -d '' -r dir; do
    contains_files "$dir" || continue
    # Remove empty .md5 file or skip this directory in read-only mode.
    if [[ -f $dir/.md5 && ! -s $dir/.md5 ]]; then
        if [[ $nogenerate ]]; then
            continue
        else
            rm "$dir/.md5"
        fi
    fi
    if [[ -f $dir/.md5 ]]; then
        echo -e "\n** Checking $dir"
        if ! check_checksum "$dir"; then
            echo "** Checksum error in $dir"
            rm "$tmpfile"
            exit 1
        fi
    else
        if [[ $nogenerate ]]; then
            continue
        fi
        echo -e "\n** Checking $dir"
        echo '** No checksum file found. Generating new checksums...'
        create_checksum "$dir"
        echo "** Finished generating checksums for $dir"
    fi
done < <(find "$base" -type d -print0)

rm "$tmpfile"
exit 0
