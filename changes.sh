#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <treeish> <master_file.tex>"
    echo "Generates a pdf with bars highlighting the changes between <treeish> and HEAD."
    exit 0
fi

old_rev=$1
new_rev=HEAD

main_file=$2

# Returns 0 if the file exists and it has no uncommitted changes.
is_clean() {
    [[ -f $1 && ! $(git status --porcelain "$1") ]]
}

add_changebars() {
    local file=$1
    local old=$(mktemp)
    local new=$(mktemp)
    git show $old_rev:$git_prefix$file > "$old"
    git show $new_rev:$git_prefix$file > "$new"
    /texlive/2010/texmf-dist/doc/latex/changebar/chbar.sh "$old" "$new" > "$file"
    rm "$old" "$new"
}

restore_file() {
    file=$1
    git checkout -- "$file"
    # The changebar commands in the aux files would cause errors on a
    # normal pdflatex run, so delete them.
    [[ ! $file =~ \.tex$ ]] || rm -f "${file%.tex}.aux"
}

dirname() {
    [[ $1 =~ / ]] && echo "${1%/*}/" || echo ''
}

get_included_files() {
    sed 's!\\include{\([^}]*\)}!'"$(dirname "$1")"'\1!;t;d' "$1"
}

find_git_prefix() {
    local git_root=$(
        while [[ ! -d .git && $(pwd) != / ]]; do
            cd ..
        done
        if [[ -d .git ]]; then
            pwd
        else
            echo 'Fatal: Not a git repository!' >&2
            exit 1
        fi
    ) || exit 1
    local cwd=$(pwd)
    local result=${cwd#$git_root}
    printf '%s' "${result#/}"
    [[ $result ]] && echo / || echo
}

make_pdf() {
    local n=6 i
    for (( i=1; i <= n; ++i )); do
        echo -n "pdflatex run #$i of $n..."
        if pdflatex -shell-escape -halt-on-error "$main_file" &>/dev/null; then
            echo 'done'
        else
            echo 'failed'
            exit 1
        fi
    done
    echo "Successfully created ${main_file%.tex}.pdf with changebars."
}

restore_files() {
    echo -n "Restoring files..."
    for f in "${files[@]}"; do
        restore_file "$f"
    done
    echo 'done'
}

cd "$(dirname "$main_file")" || exit 1
main_file=${main_file##*/}

files=( "$main_file" )
while read -r -d $'\n' file; do
    if [[ ! $file =~ \.tex$ ]]; then
        file+=.tex
    fi
    files=( "${files[@]}" "$file" )
done < <(get_included_files "$main_file")

git_prefix=$(find_git_prefix)

# Make sure all files are clean before we mess with them.
for f in "${files[@]}"; do
    if ! is_clean "$f"; then
        echo "Fatal: File has uncommitted changes: $git_prefix$f" >&2
        exit 1
    fi
done

for f in "${files[@]}"; do
    echo "Adding changebars to $git_prefix$f"
    add_changebars "$f"
done

trap restore_files EXIT

make_pdf
