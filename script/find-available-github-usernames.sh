#!/bin/bash
# Source: https://github.com/oood/find-available-github-usernames
# WARNING: The dictionary will be deleted during use, please backup the dictionary you need before starting
# Copy the dictionary and the script in the same directory, do not include the directory in the argument
# Run the script like this:
# sh ./find-available-github-usernames.sh dictionary.txt

USER="" # your_current_username
TOKEN="" # your_api_token

if [ -s "./$1" ]; then
	echo "starting..."
	echo ""$(date '+%B %d %H:%M:%S')" starting..." >> "./find-available-github-usernames.log"
	cp ./$1 ./$1.bak
	DICTIONARY="./$1"
else
	echo "error: run the script like this:"
	echo "  sh "$(cd `dirname $0`; pwd)/$(basename $0)" dictionary.txt"
	echo "copy the dictionary and the script in the same directory, do not include the directory in the argument"
	echo ""$(date '+%B %d %H:%M:%S')" error: bad dictionary argument" >> "./find-available-github-usernames.log"
	exit 1
fi

TRYAGAIN="0"

while [ -s "$DICTIONARY" ]; do
	USERNAME="$(head -1 "$DICTIONARY")"

	if [ "" != "$TOKEN" ] && [ "" != "$USER" ]; then
		HTTPCODE="$(curl -s -i -u "$USER:$TOKEN" "https://api.github.com/users/$USERNAME" -o /dev/null -w "%{http_code}")"
	else
		# Uncomment the line below only if you don't have a token, you may need proxies or you can only query 60 times per hour
		# HTTPCODE="$(curl -s -A "UsernameScript/1.0" -o /dev/null -w "%{http_code}" "https://github.com/$USERNAME")"

		echo ""$(date '+%B %d %H:%M:%S')" exit: no valid token or username" >> "./find-available-github-usernames.log" # Comment it out if you don't have a token and still want to run
		echo "no valid token or username"  # Comment it out if you don't have a token and still want to run
		exit 1  # Comment it out if you don't have a token and still want to run
	fi

	if [ "$HTTPCODE" -eq "404" ]; then
		echo "$USERNAME" >> "./found.txt"
		echo "$USERNAME found!"
	elif [ "$HTTPCODE" -eq "000" ]; then
		echo ""$(date '+%B %d %H:%M:%S')" exit: no internet connection" >> "./find-available-github-usernames.log"
		echo "exit: no internet connection"
		exit 1
	elif [ "$HTTPCODE" != "200" ]; then
		echo ""$(date '+%B %d %H:%M:%S')" warn: $HTTPCODE for $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: $HTTPCODE for $USERNAME"
		TRYAGAIN="$((TRYAGAIN + 1))"
	fi

	if [ "$TRYAGAIN" -ge "1" ] && [ "$TRYAGAIN" -le "2" ]; then
		echo ""$(date '+%B %d %H:%M:%S')" warn: try again with $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: try again with $USERNAME"
	elif [ "$TRYAGAIN" -gt "2" ]; then
		echo ""$(date '+%B %d %H:%M:%S')" warn: too many failed attempts for $USERNAME" >> "./find-available-github-usernames.log"
		echo "warn: too many failed attempts for $USERNAME"
		TRYAGAIN="0"
		sed -i '1d' "$DICTIONARY"
	elif [ "$TRYAGAIN" -eq "0" ]; then
		sed -i '1d' "$DICTIONARY"
		TRYAGAIN="0"
	fi
done

echo ""$(date '+%B %d %H:%M:%S')" exit: complete!" >> "./find-available-github-usernames.log"
echo "complete!"
exit 0
