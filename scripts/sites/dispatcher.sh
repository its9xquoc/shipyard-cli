#!/bin/bash
set -e

# ===================================================================
# ENTRY POINT FOR SITE MANAGEMENT
# ===================================================================

# Dispatcher will execute each argument as a function call.
# The actual functions must be loaded into the shell before calling the dispatcher.
# (This happens by concatenating scripts in the Laravel SetupCommand equivalent)

for func in "$@"; do
    if declare -f "$func" > /dev/null; then
        "$func"
    else
        echo "Error: Unknown step in dispatcher: $func"
    fi
done
