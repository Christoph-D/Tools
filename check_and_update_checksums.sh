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

check_checksum() { (
    cd "$1" || exit
    cfv -f .md5 || exit
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

printf '** Will check all checksums starting from %s\n' "$base"
echo '** Missing checksums will be generated automatically.'
read -p '** Proceed? [Yn]' answer

[[ ! $answer || $answer = y || $answer = Y ]] || exit 1

error=
missing=
while IFS= read -d '' -r dir; do
    echo -e "\n** Checking $dir"
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
