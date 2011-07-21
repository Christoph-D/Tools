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
nogenerate=
while [[ $# -gt 0 ]]; do
    if [[ $base = --nocheck ]]; then
        shift
        base=${1-.}
        nocheck=1
    elif [[ $base = --nogenerate ]]; then
        shift
        base=${1-.}
        nogenerate=1
    else
        shift
        break
    fi
done

if [[ ! -d $base || $# -ne 0 ]]; then
    echo "Usage: $(basename "$0") [--nocheck] [--nogenerate] [directory]"
    echo '
Verifies and updates checksum files recursively starting from the
given directory. If no directory is given, start from the current
directory.

With --nocheck no checksums are verified, only existence of files is
checked. In this mode checksum files may still be updated if files or
checksums are missing.

With --nogenerate no checksum files will be generated or modified.
This is the read-only mode.'
    exit 0
fi

if [[ $nocheck ]]; then
    printf '** Will check for missing files and missing checkums starting from %s\n' "$base"
    echo '** The checksums themselves will *not* be verified!'
else
    printf '** Will verify all checksums starting from %s\n' "$base"
fi
if [[ $nogenerate ]]; then
    echo '** Missing or wrong checksums will *not* be generated or fixed.'
    echo '** This is the read-only mode.'
else
    echo '** Missing checksums will be generated automatically.'
fi
read -p '** Proceed? [Yn]' answer

[[ ! $answer || $answer = y || $answer = Y ]] || exit 1

error=
missing=
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
            error=1
            echo "** Checksum error in $dir"
            if [[ $nogenerate ]]; then
                continue
            fi
            read -u 1 -p "** Regenerate checkums for this directory? [Yn]" answer
            if [[ ! $answer || $answer = y || $answer = Y ]]; then
                echo "** Regenerating checksums..."
                old_md5=$(mktemp)
                mv "$dir/.md5" "$old_md5"
                create_checksum "$dir"
                echo "** Finished regenerating checksums for $dir"
                mv "$old_md5" "$dir/.md5_old"
                diff "$dir/.md5_old" "$dir/.md5"
                read -u 1 -p "** Remove old .md5 file? [Yn]" answer
                if [[ ! $answer || $answer = y || $answer = Y ]]; then
                    rm "$dir/.md5_old"
                    echo "** Removed old .md5 file."
                else
                    echo "** Keeping $dir/.md5_old"
                fi
            fi
        fi
    else
        missing=1
        if [[ $nogenerate ]]; then
            continue
        fi
        echo -e "\n** Checking $dir"
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

if [[ $missing && ! $nogenerate ]]; then
    echo '** Generated some missing checksum files.'
fi

exit 0
