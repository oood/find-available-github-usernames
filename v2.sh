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
# ./v2.sh ./dictionaries/2-characters_easy-to-remember_AA.txt 10
# 10 - amount of parallel processes

# copy only <token>

# in headers starts with 
# _octo=<token>
TOKEN_1=""

# in headers starts with 
# boundary=----<token>
TOKEN_2="" # updates if you are making a lot of requests

# in headers starts with 
# user_session=<token> 
# or 
# __Host-user_session_same_site=<token>
TOKEN_3=""

# in payload starts with 
# authenticity_token: <token>
TOKEN_4="" # updates if you are making a lot of requests

################################Script Start################################

OS_TYPE=$(uname)

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "./v2.log"
    echo "$message"
}

touch v2_found.txt
FOUND_BEFORE=$(wc -l < "v2_found.txt")

# Function to clean up temporary files and kill background processes on exit
cleanup() {
    pkill -P $$
    echo -e "\n"
    log "info: Killing background processes and cleaning up temporary files..."

    PROCESSED_COUNT=$(<"$PROGRESS_FILE")
    FOUND_NOW=$(wc -l < "v2_found.txt")
    FOUND_DIFF=$((FOUND_NOW - FOUND_BEFORE))
    log "info: Found usernames: $FOUND_DIFF"
    log "info: Checked usernames: $PROCESSED_COUNT/$TOTAL_LINES"

    for i in $(seq 1 "$PARALLEL_JOBS"); do
        TEMP_FILE="$TEMP_DIR/v2_temp_chunk_$i.txt"
        if [ -s "$TEMP_FILE" ]; then
            cat "$TEMP_FILE" >> "$DICTIONARY"
            rm -f "$TEMP_FILE"
        fi
    done

    sort "$DICTIONARY" -o "$DICTIONARY"
    sort "v2_found.txt" -o "v2_found.txt"
    rm -rf "$TEMP_DIR" v2_progress.txt v2_progress.txt.lock
    exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM (kill) to run cleanup function
trap cleanup SIGINT SIGTERM

# Validate dictionary argument, variables and dependencies
if [ -s "$1" ]; then
    for program in cp curl date head rm sed sort; do
        hash "$program" >/dev/null 2>&1
        if [ "$?" -ge "1" ]; then
            log "error: Missing dependency $program, exited"
            exit 1
        fi
    done

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
TEMP_DIR="./v2_temp_chunks"
mkdir -p "$TEMP_DIR"

# Calculate total number of lines and chunk size for each job
TOTAL_LINES=$(wc -l < "$DICTIONARY")
if [ "$PARALLEL_JOBS" -gt "$TOTAL_LINES" ]; then
    PARALLEL_JOBS=$TOTAL_LINES
fi
CHUNK_SIZE=$(( TOTAL_LINES / PARALLEL_JOBS ))

# Create temporary files and distribute usernames
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/v2_temp_chunk_$i.txt"
    head -n "$CHUNK_SIZE" "$DICTIONARY" > "$TEMP_FILE"
    
    if [ "$OS_TYPE" == "Darwin"* ]; then
        sed -i '' "1,${CHUNK_SIZE}d" "$DICTIONARY"
    else
        sed -i "1,${CHUNK_SIZE}d" "$DICTIONARY"
    fi
done

# Handle any remaining lines
if [ -s "$DICTIONARY" ]; then
    cat "$DICTIONARY" >> "$TEMP_DIR/v2_temp_chunk_${PARALLEL_JOBS}.txt"
    > "$DICTIONARY"
fi

# File to track progress
PROGRESS_FILE="./v2_progress.txt"
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

    while [ -s "$TEMP_FILE" ]; do
        USERNAME="$(head -1 "$TEMP_FILE")"
        RESPONSE=$(curl -s -X POST "https://github.com/account/rename_check?suggest_usernames=true" \
          -H "Content-Type: multipart/form-data; boundary=----$TOKEN_2" \
          -H "Cookie: _octo=$TOKEN_1; user_session=$TOKEN_3; __Host-user_session_same_site=$TOKEN_3" \
          --data-raw $'------'$TOKEN_2$'\r\nContent-Disposition: form-data; name="suggest_usernames"\r\n\r\ntrue\r\n------'$TOKEN_2$'\r\nContent-Disposition: form-data; name="authenticity_token"\r\n\r\n'$TOKEN_4$'\r\n------'$TOKEN_2$'\r\nContent-Disposition: form-data; name="value"\r\n\r\n'$USERNAME$'\r\n------'$TOKEN_2$'--\r\n')

        if echo "$RESPONSE" | grep -q "is available."; then
            echo "$USERNAME" >> "./v2_found.txt"
            log "info: Thread $THREAD_ID: $USERNAME found!"
        # elif echo "$RESPONSE" | grep -q "must be different."; then
            
        # elif echo "$RESPONSE" | grep -q "is not available."; then
        elif ! (echo "$RESPONSE" | grep -q "must be different." || echo "$RESPONSE" | grep -q "is not available."); then
            log "warn: Unknown response for $USERNAME"
            cleanup
        # else
        #     log "warn: Unknown response for $USERNAME"
        #     cleanup
        fi

        if [ "$OS_TYPE" == "Darwin"* ]; then
            sed -i '' "/$USERNAME/d" "$TEMP_FILE"
        else
            sed -i "/$USERNAME/d" "$TEMP_FILE"
        fi

        update_progress true
    done
}

# Generate workers
for i in $(seq 1 "$PARALLEL_JOBS"); do
    TEMP_FILE="$TEMP_DIR/v2_temp_chunk_$i.txt"
    (
        handle_username_check "$BASHPID" "$TEMP_FILE"
    ) &
done

wait

# Complete
echo -e "\n"
log "info: Complete!"
cleanup