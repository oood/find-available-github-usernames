#!/bin/bash
# Source: https://github.com/oood/find-available-github-usernames
# WARNING: The dictionary will be deleted during use, please backup the dictionary you need before starting
# Copy the dictionary and the script in the same directory, do not include the directory in the argument
# Run the script like this:
# sh ./find-available-github-usernames.sh dictionary.txt

user="" # your_current_username
token="" # your_api_token

if [ -s "./$1" ]; then
	echo "starting..."
	echo ""$(date '+%Y-%m-%d %H:%M:%S')" starting..." >> "./find-available-github-usernames.log"
	cp ./$1 ./$1.bak
	dictionary="./$1"
else
	echo "error: run the script like this:"
	echo "  sh "$(cd `dirname $0`; pwd)/$(basename $0)" dictionary.txt"
	echo "copy the dictionary and the script in the same directory, do not include the directory in the argument"
	echo ""$(date '+%Y-%m-%d %H:%M:%S')" error: bad dictionary argument" >> "./find-available-github-usernames.log"
	exit 1
fi

tryagain="0"

while [ -s "$dictionary" ]; do
	username="$(head -1 "$dictionary")"

	if [ "" != "$token" ] && [ "" != "$user" ]; then
		httpcode="$(curl -s -i -u "$user:$token" "https://api.github.com/users/$username" -o /dev/null -w "%{http_code}")"
	else
		# Uncomment the line below only if you don't have a token, you may need proxies or you can only query 60 times per hour
		# httpcode="$(curl -s -A "UsernameScript/1.0" -o /dev/null -w "%{http_code}" "https://github.com/$username")"

		echo ""$(date '+%Y-%m-%d %H:%M:%S')" exit: no valid token or username" >> "./find-available-github-usernames.log" # Comment it out if you don't have a token and still want to run
		echo "no valid token or username"  # Comment it out if you don't have a token and still want to run
		exit 1  # Comment it out if you don't have a token and still want to run
	fi

	if [ "$httpcode" -eq "404" ]; then
		echo "$username" >> "./found.txt"
		echo "$username found!"
	elif [ "$httpcode" -eq "000" ]; then
		echo ""$(date '+%Y-%m-%d %H:%M:%S')" exit: no internet connection" >> "./find-available-github-usernames.log"
		echo "exit: no internet connection"
		exit 1
	elif [ "$httpcode" != "200" ]; then
		echo ""$(date '+%Y-%m-%d %H:%M:%S')" warn: $httpcode for $username" >> "./find-available-github-usernames.log"
		echo "warn: $httpcode for $username"
		tryagain="$((tryagain + 1))"
	fi

	if [ "$tryagain" -ge "1" ] && [ "$tryagain" -le "2" ]; then
		echo ""$(date '+%Y-%m-%d %H:%M:%S')" warn: try again with $username" >> "./find-available-github-usernames.log"
		echo "warn: try again with $username"
	elif [ "$tryagain" -gt "2" ]; then
		echo ""$(date '+%Y-%m-%d %H:%M:%S')" warn: too many failed attempts for $username" >> "./find-available-github-usernames.log"
		echo "warn: too many failed attempts for $username"
		tryagain="0"
		sed -i '1d' "$dictionary"
	elif [ "$tryagain" -eq "0" ]; then
		sed -i '1d' "$dictionary"
		tryagain="0"
	fi
done

echo ""$(date '+%Y-%m-%d %H:%M:%S')" exit: complete!" >> "./find-available-github-usernames.log"
echo "complete!"
exit 0
