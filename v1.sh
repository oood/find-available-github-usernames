#!/bin/bash
# Source: https://github.com/oood/find-available-github-usernames
#
# The dictionary will be deleted line by line during use. the purpose
# of this is that the script can be terminated at any time, and the next
# time it starts, it will continue to load from the position where it
# ended last time, and the script will create a backup .bak dictionary
# before starting.
#
# Run the script like this:
# ./v1.sh ./dictionaries/2-characters_easy-to-remember_AA.txt 10
# 10 - amount of parallel processes

USER="" # your_current_username
TOKEN="" # your_api_token

################################Script Start################################

OS_TYPE=$(uname)

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "./v1.log"
    echo "$message"
}

# Function to display GitHub API rate limits
show_rate_limits() {
    if [ -n "$TOKEN" ]; then
        RESPONSE=$(curl -s -u "$USER:$TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit)
    else
        log "info: TOKEN is empty"
        RESPONSE=$(curl -s -u "$USER:" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit)
    fi

    LIMIT=$(echo "$RESPONSE" | jq '.rate.limit')
    USED=$(echo "$RESPONSE" | jq '.rate.used')
    REMAINING=$(echo "$RESPONSE" | jq '.rate.remaining')
    RESET=$(echo "$RESPONSE" | jq '.rate.reset')

    if [ "$OS_TYPE" == "Darwin"* ]; then
        RESET_TIME=$(date -u -r "$RESET" +"%Y-%m-%d %H:%M:%S")
    else
        RESET_TIME=$(date -d @"$RESET" +"%Y-%m-%d %H:%M:%S")
    fi

    log "info: Limit: $LIMIT"
    log "info: Used: $USED"
    log "info: Remaining: $REMAINING"
    log "info: Reset time: $RESET_TIME"
}

if [[ "$1" == "--api" ]]; then
    show_rate_limits
    exit 0
fi

touch v1_found.txt
FOUND_BEFORE=$(wc -l < "v1_found.txt")

# Function to clean up temporary files and kill background processes on exit
cleanup() {
    pkill -P $$
    echo -e "\n"
    log "info: Killing background processes and cleaning up temporary files..."

    PROCESSED_COUNT=$(<"$PROGRESS_FILE")
    FOUND_NOW=$(wc -l < "v1_found.txt")
    FOUND_DIFF=$((FOUND_NOW - FOUND_BEFORE))
    log "info: Found usernames: $FOUND_DIFF"
    log "info: Checked usernames: $PROCESSED_COUNT/$TOTAL_LINES"

    for i in $(seq 1 "$PARALLEL_JOBS"); do
        TEMP_FILE="$TEMP_DIR/v1_temp_chunk_$i.txt"
        if [ -s "$TEMP_FILE" ]; then
            cat "$TEMP_FILE" >> "$DICTIONARY"
            rm -f "$TEMP_FILE"
        fi
    done

    sort "$DICTIONARY" -o "$DICTIONARY"    
    sort "v1_found.txt" -o "v1_found.txt"
    rm -rf "$TEMP_DIR" v1_progress.txt v1_progress.txt.lock
    show_rate_limits
    exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM (kill) to run cleanup function
trap cleanup SIGINT SIGTERM

# Validate dictionary argument, variables and dependencies
if [ -s "$1" ]; then
    for program in cp curl date head rm sed sort jq; do
        hash "$program" >/dev/null 2>&1
        if [ "$?" -ge "1" ]; then
            log "error: Missing dependency $program, exited"
            exit 1
        fi
    done

    if [ -z "$USER" ]; then
        log "error: USER is not set"
        exit 1
    fi

    if [ -z "$TOKEN" ]; then
        log "warn: TOKEN is not set"
    fi

    show_rate_limits
    echo -e ""
    log "info: Starting..."
    cp "$1" "$1.bak"
    DICTIONARY="$(realpath "$1")"
else
    log "error: Bad dictionary argument"
    exit 1
fi

PARALLEL_JOBS="${2:-1}"

# Create a temporary directory for chunk files
TEMP_DIR="./v1_temp_chunks"
mkdir -p "$TEMP_DIR"

# Calculate total number of lines and chunk size for each job
TOTAL_LINES=$(wc -l < "$DICTIONARY")
if [ "$PARALLEL_JOBS" -gt "$TOTAL_LINES" ]; then
    PARALLEL_JOBS=$TOTAL_LINES
fi
CHUNK_SIZE=$(( TOTAL_LINES / PARALLEL_JOBS ))

# Create temporary files and distribute usernames
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/v1_temp_chunk_$i.txt"
    head -n "$CHUNK_SIZE" "$DICTIONARY" > "$TEMP_FILE"

    if [ "$OS_TYPE" == "Darwin"* ]; then
        sed -i '' "1,${CHUNK_SIZE}d" "$DICTIONARY"
    else
        sed -i "1,${CHUNK_SIZE}d" "$DICTIONARY"
    fi
done

# Handle any remaining lines
if [ -s "$DICTIONARY" ]; then
    cat "$DICTIONARY" >> "$TEMP_DIR/v1_temp_chunk_${PARALLEL_JOBS}.txt"
    > "$DICTIONARY"
fi

# File to track progress
PROGRESS_FILE="./v1_progress.txt"
echo "0" > "$PROGRESS_FILE"

if [[ "$OS_TYPE" == "Darwin"* ]]; then
    LOCK_CMD="shlock -f \"$PROGRESS_FILE.lock\" -p $$"
    UNLOCK_CMD="rm -f \"$PROGRESS_FILE.lock\""
else
    LOCK_CMD="flock -x 200"
    UNLOCK_CMD="flock -u 200"
fi

update_progress() {
    {
        eval "$LOCK_CMD"
        PROCESSED_COUNT=$(<"$PROGRESS_FILE")
        if [ "$1" = true ]; then
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
            echo "$PROCESSED_COUNT" > "$PROGRESS_FILE"
        fi
        tput el
        printf "Progress: %d/%d\r" "$PROCESSED_COUNT" "$TOTAL_LINES"
        
        eval "$UNLOCK_CMD"
    } 200>"$PROGRESS_FILE.lock"
}

# Worker
handle_username_check() {
    THREAD_ID=$1
    TEMP_FILE=$2
    TRYAGAIN="0"

    while [ -s "$TEMP_FILE" ]; do
        USERNAME="$(head -1 "$TEMP_FILE")"

        HTTPCODE=$(curl -fsi -u "$USER:$TOKEN" "https://api.github.com/users/${USERNAME}" -o /dev/null -w "%{http_code}")

        if [ -n "$HTTPCODE" ] && [ "$HTTPCODE" -eq "404" ]; then
            echo "$USERNAME" >> "./v1_found.txt"
            log "info: Thread $THREAD_ID: $USERNAME found!"
        elif [ -n "$HTTPCODE" ] && [ "$HTTPCODE" -eq "000" ]; then
            log "warn: Thread $THREAD_ID: No internet connection"
            log "warn: Thread $THREAD_ID: Retrying in 2 seconds..."
            sleep 2
            TRYAGAIN="$((TRYAGAIN + 1))"
        elif [ -n "$HTTPCODE" ] && [ "$HTTPCODE" -eq "403" ]; then
            log "warn: Thread $THREAD_ID: $HTTPCODE for $USERNAME"
            cleanup
        elif [ -n "$HTTPCODE" ] && [ "$HTTPCODE" != "200" ]; then
            log "warn: Thread $THREAD_ID: $HTTPCODE for $USERNAME"
            TRYAGAIN="$((TRYAGAIN + 1))"
        fi

        if [ "$TRYAGAIN" -ge "1" ] && [ "$TRYAGAIN" -le "2" ]; then
            log "warn: Thread $THREAD_ID: Try again with $USERNAME"
            update_progress false
        elif [ "$TRYAGAIN" -gt "2" ]; then
            log "warn: Thread $THREAD_ID: Too many failed attempts for $USERNAME"
            cleanup
        elif [ "$TRYAGAIN" -eq "0" ]; then
            TRYAGAIN="0"
            
            if [ "$OS_TYPE" == "Darwin"* ]; then
                sed -i '' "/$USERNAME/d" "$TEMP_FILE"
            else
                sed -i "/$USERNAME/d" "$TEMP_FILE"
            fi

            update_progress true
        fi
    done
}

# Generate workers
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/v1_temp_chunk_$i.txt"
    (
        handle_username_check "$BASHPID" "$TEMP_FILE"
    ) &
done

wait

# Complete
echo -e "\n"
log "info: Complete!"
cleanup