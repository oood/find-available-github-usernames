#!/bin/bash

DICTIONARY_PATH="$(realpath "$1")"
SCRIPT_PATH="./v2.sh"
PARALLEL_JOBS=100

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "./v2.log"
    echo "$message"
}

while true; do
    if [ -s "$DICTIONARY_PATH" ]; then
        log "info: Starting script as $DICTIONARY_PATH is not empty..."
        $SCRIPT_PATH "$DICTIONARY_PATH" "$PARALLEL_JOBS"
    else
        log "info: File $DICTIONARY_PATH is empty. Exiting loop"
        break
    fi

    sleep 60
done

log "info: All tasks completed"
