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

contains_files() {
    [[ $(find "$1" -maxdepth 1 -type f -printf . -quit) ]]
}

check_checksum() { (
    cd "$1" || exit
    if [[ $nocheck ]]; then
        cfv -m -f .md5 || exit
    else
        cfv -f .md5 || exit
    fi
    unknown=
    while IFS= read -d '' -r filename; do
        filename=$(basename "$filename")
        [[ $filename != .md5 ]] || continue
        if ! grep -q " \*$(escape_for_grep "$filename")$" .md5; then
            unknown=1
            printf 'Missing checksum for: %s\n' "$dir/$filename"
        fi
    done < <(find . -maxdepth 1 -type f -print0)
    [[ ! $unknown ]]
) }

create_checksum() { (
    cd "$1" || exit
    cfv -C -tmd5 -f .md5
) }

base=${1-.}
nocheck=
if [[ $base = --nocheck ]]; then
    shift
    base=${1-.}
    nocheck=1
fi

if [[ ! -d $base || ( $# -ne 1 && $# -ne 0 ) ]]; then
    echo "Usage: $(basename "$0") [--nocheck] [directory]"
    echo '
Verifies and updates checksum files recursively starting from the
given directory. If no directory is given, start from the current
directory.

With --nocheck no checksums are verified, only existence of files is
checked. In this mode checksum files may still be updated if files or
checksums are missing.'
    exit 0
fi

if [[ $nocheck ]]; then
    printf '** Will check for missing files and missing checkums starting from %s\n' "$base"
    echo '** The checksums themselves will *not* be verified!'
else
    printf '** Will verify all checksums starting from %s\n' "$base"
fi
echo '** Missing checksums will be generated automatically.'
read -p '** Proceed? [Yn]' answer

[[ ! $answer || $answer = y || $answer = Y ]] || exit 1

error=
missing=
while IFS= read -d '' -r dir; do
    echo -e "\n** Checking $dir"
    contains_files "$dir" || { echo 'No files to check.'; continue; }
    if [[ -s $dir/.md5 ]]; then
        if ! check_checksum "$dir"; then
            error=1
            echo "** Checksum error in $dir"
            read -u 1 -p "** Regenerate checkums for this directory? [Yn]" answer
            if [[ ! $answer || $answer = y || $answer = Y ]]; then
                echo "** Regenerating checksums..."
                rm "$dir/.md5"
                create_checksum "$dir"
                echo "** Finished regenerating checksums for $dir"
            fi
        fi
    else
        missing=1
        echo '** No checksum file found. Generating new checksums...'
        create_checksum "$dir"
        echo "** Finished generating checksums for $dir"
    fi
done < <(find "$base" -type d -print0)

echo
if [[ $error ]]; then
    echo '** Errors were encountered.'
else
    echo '** No errors were encountered.'
fi

if [[ $missing ]]; then
    echo '** Generated some missing checksum files.'
fi

exit 0
