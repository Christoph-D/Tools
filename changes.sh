#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <treeish> <master_file.tex>"
    echo 'Generates a pdf with bars highlighting the changes between <treeish> and HEAD.'
    echo 
    echo 'This script comes WITHOUT ANY WARRANTY.'
    echo 'Please backup your work before you try it.'
    exit 0
fi

chbar=/texlive/2010/texmf-dist/doc/latex/changebar/chbar.sh

if [[ ! -x $chbar ]]; then
    echo "Fatal: $chbar does not exist or is not executable."
    echo 'Please change the variable chbar in this script.'
    exit 1
fi

old_rev=$1
new_rev=HEAD
main_file=$2

# Returns 0 if the file exists and it has no uncommitted changes.
is_clean() {
    [[ -f $1 && ! $(git status --porcelain "$1" 2>&1) ]]
}

# Adds changebars to the given file. Requires the global variables
# git_prefix, old_rev and new_rev.
add_changebars() {
    local file=$1
    local old=$(mktemp)
    git show $old_rev:$git_prefix$file > "$old"
    git show $new_rev:$git_prefix$file | "$chbar" "$old" > "$file"
    rm "$old"
}

# Updates the definition of \VCDiff in the given file. Requires the
# global variable old_rev.
add_diff_notice() {
    local notice="(differences to $(git rev-parse --short "$old_rev") marked)"
    sed -i 's!\\newcommand{\\VCDiff}{}!\\newcommand{\\VCDiff}{'"$notice"'}!' "$1"
}

# Brings all files back to a pristine state.
restore_files() {
    echo -n "Restoring files..."
    for f in "${files[@]}"; do
        git checkout -- "$f"
        # The changebar commands in the aux files would cause errors on a
        # normal pdflatex run, so delete them.
        [[ ! $f =~ \.tex$ ]] || rm -f "${f%.tex}.aux"
    done
    # Also remove a possibly outdated bibtex file.
    rm -f "${main_file%.tex}.bbl"
    echo 'done'
}

# We need a dirname that returns the empty string if there is no / in
# the parameter.
dirname() {
    [[ $1 =~ / ]] && echo "${1%/*}/" || echo ''
}

# Heuristic to figure out which other tex files the master file
# includes.
get_included_files() {
    sed 's!\\include{\([^}]*\)}!'"$(dirname "$1")"'\1!;t;d' "$1"
}

# Prints a path git_prefix on stdout such that for all existing paths
# f relative to the current working directory the string
# HEAD:$git_prefix$f is a proper revision as recognized by
# git-parse-rev (with f not containing '..').
#
# Or in other words, we can use git_prefix to turn (a subset of) the
# paths relative to cwd into paths relative to the root of the git
# repo.
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

# Runs pdflatex several times. Also calls bibtex once.
make_pdf() {
    local n=6 i
    for (( i=1; i <= n; ++i )); do
        if [[ $i -eq 2 ]]; then
            echo -n "Calling bibtex..."
            bibtex "${main_file%.tex}" &>/dev/null
            echo 'done'
        fi
        echo -n "pdflatex run #$i of $n..."
        if pdflatex -shell-escape -halt-on-error -interaction nonstopmode \
            "$main_file" &>/dev/null; then
            echo 'done'
        else
            echo 'failed'
            exit 1
        fi
    done
    echo "Successfully created ${main_file%.tex}.pdf with changebars."
}

# We want to work in the directory of the master file.
cd "$(dirname "$main_file")" || exit 1
main_file=${main_file##*/}

# Collect file names.
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
add_diff_notice "$main_file"

trap restore_files EXIT

make_pdf
