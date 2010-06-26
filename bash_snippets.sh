#!/bin/bash
# Just some code snippets I don't want to lose.

set -e -u

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

exit 0
