#!/bin/bash

DICTIONARY_PATH="$(realpath "$1")"
SCRIPT_PATH="./rename-check.sh"
PARALLEL_JOBS=100

while true; do
    if [ -s "$DICTIONARY_PATH" ]; then
        echo "Starting script as $DICTIONARY_PATH is not empty..."
        $SCRIPT_PATH "$DICTIONARY_PATH" "$PARALLEL_JOBS"
    else
        echo "File $DICTIONARY_PATH is empty. Exiting loop."
        break
    fi

    sleep 60
done

echo "All tasks completed."
