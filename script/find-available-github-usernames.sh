#!/bin/bash
# Source: https://github.com/oood/find-available-github-usernames
#
# The dictionary will be deleted line by line during use. the purpose
# of this is that the script can be terminated at any time, and the next
# time it starts, it will continue to load from the position where it
# ended last time, and the script will create a backup .bak dictionary
# before starting.
#
# Copy the dictionary and the script in the same directory, do not include
# the directory in the argument.
# Run the script like this:
# sh ./find-available-github-usernames.sh dictionary.txt

USER="" # your_current_username
TOKEN="" # your_api_token

################################Script Start################################


# Check the argument, check dependencies, create a dictionary backup
if [ -s "./$1" ]; then
	for program in cp curl date head rm sed; do
		hash "$program" >/dev/null 2>&1
		if [ "$?" -ge "1" ]; then
			echo "error: missing dependency $program, exited"
			echo "$(date '+%Y-%m-%d %H:%M:%S') error: missing dependency $program, exited." >> "./find-available-github-usernames.log"
			exit 1
		fi
	done
	echo "starting..."
	echo "$(date '+%Y-%m-%d %H:%M:%S') starting..." >> "./find-available-github-usernames.log"
	cp "./$1" "./$1.bak"
	DICTIONARY="./$1"
else
	echo "error: run the script like this:"
	echo "  sh $(cd $(dirname $0); pwd)/$(basename $0) dictionary.txt"
	echo "copy the dictionary and the script in the same directory, do not include the directory in the argument"
	echo "$(date '+%Y-%m-%d %H:%M:%S') error: bad dictionary argument" >> "./find-available-github-usernames.log"
	exit 1
fi


# Start loop checking
TRYAGAIN="0"
while [ -s "$DICTIONARY" ]; do
	USERNAME="$(head -1 "$DICTIONARY")"

	if [ -n "$TOKEN" ] && [ -n "$USER" ]; then
		HTTPCODE="$(curl -fsi -u "$USER:$TOKEN" "https://api.github.com/users/${USERNAME}" -o /dev/null -w "%{http_code}")"
	else
		# Uncomment the line below only if you don't have a token, you may need proxies or you can only query 60 times per hour
		# HTTPCODE="$(curl -fs -A "UsernameScript/1.0" -o /dev/null -w "%{http_code}" "https://github.com/${USERNAME}")"

		echo "$(date '+%Y-%m-%d %H:%M:%S') exit: no valid token or username" >> "./find-available-github-usernames.log" # Comment it out if you don't have a token and still want to run
		echo "no valid token or username" # Comment it out if you don't have a token and still want to run
		exit 1 # Comment it out if you don't have a token and still want to run
	fi

	if [ "$HTTPCODE" -eq "404" ]; then
		echo "$USERNAME" >> "./found.txt"
		echo "$USERNAME found!"
	elif [ "$HTTPCODE" -eq "000" ]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') exit: no internet connection" >> "./find-available-github-usernames.log"
		echo "exit: no internet connection"
		exit 1
	elif [ "$HTTPCODE" != "200" ]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') warn: $HTTPCODE for $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: $HTTPCODE for $USERNAME"
		TRYAGAIN="$((TRYAGAIN + 1))"
	fi

	if [ "$TRYAGAIN" -ge "1" ] && [ "$TRYAGAIN" -le "2" ]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') warn: try again with $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: try again with $USERNAME"
	elif [ "$TRYAGAIN" -gt "2" ]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') warn: too many failed attempts for $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: too many failed attempts for $USERNAME"
		TRYAGAIN="0"
		sed -i.backup -e '1d' "$DICTIONARY"
	elif [ "$TRYAGAIN" -eq "0" ]; then
		sed -i.backup -e '1d' "$DICTIONARY"
		TRYAGAIN="0"
	fi
done
rm -f "$DICTIONARY.backup"
if [ ! -s "$DICTIONARY" ]; then
	rm -f "$DICTIONARY"
fi


# Complete
echo "$(date '+%Y-%m-%d %H:%M:%S') exit: complete!" >> "./find-available-github-usernames.log"
echo "complete!"
exit 0
