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
# sh ./find-available-github-usernames.sh dictionary.txt 10
# 10 - amount of parallel processes

USER="" # your_current_username
TOKEN="" # your_api_token

################################Script Start################################

# Function to display GitHub API rate limits
show_rate_limits() {
    if [ -n "$TOKEN" ]; then
        RESPONSE=$(curl -s -u "$USER:$TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit)
    else
        echo "TOKEN is empty"
        RESPONSE=$(curl -s -u "$USER:" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit)
    fi

    LIMIT=$(echo "$RESPONSE" | jq '.rate.limit')
    USED=$(echo "$RESPONSE" | jq '.rate.used')
    REMAINING=$(echo "$RESPONSE" | jq '.rate.remaining')
    RESET=$(echo "$RESPONSE" | jq '.rate.reset')
    RESET_TIME=$(date -d @"$RESET" +"%Y-%m-%d %H:%M:%S")

    echo "Limit: $LIMIT"
    echo "Used: $USED"
    echo "Remaining: $REMAINING"
    echo "Reset time: $RESET_TIME"

    echo "$(date '+%Y-%m-%d %H:%M:%S') info: Limit: $LIMIT" >> "./find-available-github-usernames.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') info: Used: $USED" >> "./find-available-github-usernames.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') info: Remaining: $REMAINING" >> "./find-available-github-usernames.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') info: Reset time: $RESET_TIME" >> "./find-available-github-usernames.log"
}

if [[ "$1" == "--api" ]]; then
    show_rate_limits
    exit 0
fi

touch found.txt
FOUND_BEFORE=$(wc -l < "found.txt")

# Function to clean up temporary files and kill background processes on exit
cleanup() {
    pkill -P $$
    echo -e "\nKilling background processes and cleaning up temporary files...\n"


    PROCESSED_COUNT=$(<"$PROGRESS_FILE")
    FOUND_NOW=$(wc -l < "found.txt")
    FOUND_DIFF=$((FOUND_NOW - FOUND_BEFORE))
    echo -e "Found usernames: $FOUND_DIFF"
    echo -e "Checked usernames: $PROCESSED_COUNT/$TOTAL_LINES"

    for i in $(seq 1 "$PARALLEL_JOBS"); do
        TEMP_FILE="$TEMP_DIR/temp_chunk_$i.txt"
        if [ -s "$TEMP_FILE" ]; then
            cat "$TEMP_FILE" >> "$DICTIONARY"
            rm -f "$TEMP_FILE"
        fi
    done

    sort "$DICTIONARY" -o "$DICTIONARY"    
    rm -rf "$TEMP_DIR" progress.txt progress.txt.lock
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
            echo "error: missing dependency $program, exited"
            echo "$(date '+%Y-%m-%d %H:%M:%S') error: missing dependency $program, exited." >> "./find-available-github-usernames.log"
            exit 1
        fi
    done

    if [ -z "$USER" ]; then
        echo "error: USER is not set"
        echo "$(date '+%Y-%m-%d %H:%M:%S') error: USER is not set or empty" >> "./find-available-github-usernames.log"
        exit 1
    fi

    if [ -z "$TOKEN" ]; then
        echo "error: TOKEN is not set"
        echo "$(date '+%Y-%m-%d %H:%M:%S') error: TOKEN is not set" >> "./find-available-github-usernames.log"
    fi

    show_rate_limits
    echo -e "\nStarting...\n"
    echo "$(date '+%Y-%m-%d %H:%M:%S') info: Starting..." >> "./find-available-github-usernames.log"
    cp "$1" "$1.bak"
    DICTIONARY="$(realpath "$1")"
else
    echo "error: bad dictionary argument"
    echo "$(date '+%Y-%m-%d %H:%M:%S') error: bad dictionary argument" >> "./find-available-github-usernames.log"
    exit 1
fi

PARALLEL_JOBS="${2:-1}"

# Create a temporary directory for chunk files
TEMP_DIR="./temp_chunks"
mkdir -p "$TEMP_DIR"

# Calculate total number of lines and chunk size for each job
TOTAL_LINES=$(wc -l < "$DICTIONARY")
if [ "$PARALLEL_JOBS" -gt "$TOTAL_LINES" ]; then
    PARALLEL_JOBS=$TOTAL_LINES
fi
CHUNK_SIZE=$(( TOTAL_LINES / PARALLEL_JOBS ))

# Create temporary files and distribute usernames
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/temp_chunk_$i.txt"
    head -n "$CHUNK_SIZE" "$DICTIONARY" > "$TEMP_FILE"
    sed -i "1,${CHUNK_SIZE}d" "$DICTIONARY"
done

# Handle any remaining lines
if [ -s "$DICTIONARY" ]; then
    cat "$DICTIONARY" >> "$TEMP_DIR/temp_chunk_${PARALLEL_JOBS}.txt"
    > "$DICTIONARY"
fi

# File to track progress
PROGRESS_FILE="./progress.txt"
echo "0" > "$PROGRESS_FILE"

# Function to update progress and display
update_progress() {
    {
        flock -x 200
        PROCESSED_COUNT=$(<"$PROGRESS_FILE")
        if [ "$1" = true ]; then
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
            echo "$PROCESSED_COUNT" > "$PROGRESS_FILE"
        fi
        echo -ne "Progress: $PROCESSED_COUNT/$TOTAL_LINES\r"
        flock -u 200
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
            echo "thread $THREAD_ID: $USERNAME found!"
            echo "$USERNAME" >> "./found.txt"
        elif [ -n "$HTTPCODE" ] && [ "$HTTPCODE" -eq "000" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') exit: no internet connection" >> "./find-available-github-usernames.log"
            echo "thread $THREAD_ID: exit: no internet connection"
            echo "thread $THREAD_ID: retrying in 5 seconds..."
            sleep 2
            continue
        elif [ -n "$HTTPCODE" ] && [ "$HTTPCODE" != "200" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') warn: $HTTPCODE for $USERNAME" >> "./find-available-github-usernames.log"
            echo "thread $THREAD_ID: warn: $HTTPCODE for $USERNAME"
            TRYAGAIN="$((TRYAGAIN + 1))"
        fi

        if [ "$TRYAGAIN" -ge "1" ] && [ "$TRYAGAIN" -le "2" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') warn: try again with $USERNAME" >> "./find-available-github-usernames.log"
            echo "thread $THREAD_ID: warn: try again with $USERNAME"
            update_progress false
        elif [ "$TRYAGAIN" -gt "2" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') warn: too many failed attempts for $USERNAME" >> "./find-available-github-usernames.log"
            echo "thread $THREAD_ID: warn: too many failed attempts for $USERNAME"
            TRYAGAIN="0"
            sed -i "/$USERNAME/d" "$TEMP_FILE"
            update_progress true
        elif [ "$TRYAGAIN" -eq "0" ]; then
            TRYAGAIN="0"
            sed -i "/$USERNAME/d" "$TEMP_FILE"
            update_progress true
        fi
    done
}

# Generate workers
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/temp_chunk_$i.txt"
    (
        handle_username_check "$BASHPID" "$TEMP_FILE"
    ) &
done

wait

# Complete
echo "$(date '+%Y-%m-%d %H:%M:%S') exit: complete!" >> "./find-available-github-usernames.log"
echo -e "\ncomplete!"
cleanup