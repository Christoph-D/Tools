#!/bin/bash
# Just some code snippets I don't want to lose.

set -e -u

echo '* Stack traces in bash:'

# Prints a stack trace to stderr.
print_callstack() {
    echo '*** stack trace [line function file] ***' >&2
    local I=0
    while caller $I >&2; do
        let ++I
    done
    echo '*** end of trace ***' >&2
}

# Test the stack trace.
g() { print_callstack; }
f() { g; }
f


echo -e '\n\n* Function "run":'

# Runs the given command in the current environment, i.e. not in a
# subshell. Standard output is returned in the global variable $STDOUT
# and standard error in $STDERR.
run() {
    # Prepare
    local STDOUT_FILE= STDERR_FILE=
    local OLD_EXIT_TRAP=$(trap -p EXIT | sed 's/^trap -- \(.*\) EXIT$/\1/')
    local TRAP_WAS_SET="${OLD_EXIT_TRAP:0:1}"
    # Unquote $OLD_EXIT_TRAP.
    OLD_EXIT_TRAP=$(eval printf '%s' $OLD_EXIT_TRAP)
    # Insert our clean-up function.
    trap "rm -f '$STDOUT_FILE' '$STDERR_FILE'; $OLD_EXIT_TRAP" EXIT
    STDOUT_FILE=$(mktemp)
    STDERR_FILE=$(mktemp)

    # Run
    "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE"

    # Clean up
    STDOUT=$(cat "$STDOUT_FILE")
    STDERR=$(cat "$STDERR_FILE")
    rm -f "$STDOUT_FILE" "$STDERR_FILE"
    # Restore the old EXIT trap.
    [[ $TRAP_WAS_SET ]] && trap "$OLD_EXIT_TRAP" EXIT || trap EXIT
}

test_run () {
    echo "$1"
    echo "$2" >&2
    G=42
}

run test_run "One line on stdout" "and one more on stderr."
echo "G = $G (should be 42)"
echo "STDOUT = [[$STDOUT]]"
echo "STDERR = [[$STDERR]]"

exit 0
