# Hello World

:octocat: Hello world, this is my first repository, I wanted to share some stories of how I picked my GitHub username.



## What is a good username on GitHub?

Because GitHub isn't exactly like social media, when you've built a lot of important repositories, the cost of changing your username increases, you have to accept your username or create a new account, I think it's not an option for many people, So it's better to clearly consider your needs before registering an account, not only nice and cool names, but also easy to type, the shorter the better.



## What did I do?

GitHub allows everyone to check user pages, I initially wrote a [script](https://github.com/oood/find-available-github-usernames/tree/main/script) and created some dictionaries with character combinations to check all URLs `https://github.com/$username`. this worked fine at first, but unfortunately after a few minutes I triggered an `Error: 429 Too many requests`, so I started searching to see if there was a better way, and I found that GitHub provides an API [[1]](#1) that can be used to retrieve registered username and available username, but I don't have an account how can I get an API token?


There are two ways: First, register an account with any username, then get the API token and then find the appropriate username and modify it. Or bypass the restriction with proxies :shipit:, which I know is rude, so I chose the first way.


GitHub serves 5,000 requests per hour for users using the API [[1]](#1), which seems a bit low considering the short usernames that are still available from millions of usernames, but compared to only 60 requests per IP per hour without the API, that's a huge difference.


I generated the 2-character dictionary and found some "available" usernames, but I found out that they were just reserved usernames, then I tried the 3-character dictionary again, this time I didn't intend to check all 3-characters, because I didn't want to wait too long, and all combinations were already well over the limit of 5,000 per hour, I generated `easy-to-remember` dictionaries from all combinations, then I didn't find a username that worked for me, and finally I found my current username in a 4-character `easy-to-remember` dictionary.


## What can you do?

Register GitHub, then click on your avatar in the upper right corner, enter `Settings`, click on the left to enter `Developer Settings`, and generate a `Personal Access Token`.


Next download or clone this repository, use the dictionary provided in the repository or generate your own, copy a dictionary and the script in the same directory, edit the script and fill in your current GitHub username and token, run the following command:

````sh
# sh ./find-available-github-usernames.sh <file.txt> <threads>
sh ./find-available-github-usernames.sh dictionary.txt 10
````

To get information about api limits:
````sh
sh ./find-available-github-usernames.sh --api
````
Response example:
```sh
> ./find-available-github-usernames.sh --api
TOKEN is empty
Limit: 60
Used: 46
Remaining: 14
Reset time: 2024-10-21 20:11:20
```
**Notes:**


The working principle of the script is very simple, import the first line of the dictionary, check whether the username is available, if got `HTTP: 404`, add it to the `found.txt`, if encounter an error, print and output to the `find-available-github-usernames.log`, and finally delete all checked lines in the dictionary.


The reason for deleting the lines in the dictionary is to ensure that the task can be terminated at any time by pressing `^c` (Ctrl+C) in the terminal and don't have to start from the beginning on the next run.


The first time the script is run, a backup file with a `.bak` suffix is generated for the dictionary.


[Get dictionaries](https://github.com/oood/find-available-github-usernames/tree/main/dictionaries)


[Get script](https://github.com/oood/find-available-github-usernames/tree/main/script)


## FAQs


### Dictionary file name meaning?

`2-characters_00-99_AA-ZZ.txt` Consists of 2 characters, including all combinations of letters and digits.


`3-characters_AAA-ZZZ.txt` and `4-characters_AAAA-ZZZZ.txt` Contains all combinations of all 3 and 4 letters, no digits.


`XX-characters_easy-to-remember_XX.txt` Usernames with repeated characters.


### What is the difference between full dictionary and `easy-to-remember`?

I recommend trying the `easy-to-remember` ones in my dictionaries first, as those that have some kind of regularity, like multiple occurrences of the same character, and easier to type. other dictionaries are full dictionaries, which means they may contain thousands of usernames.


### How do I generate a dictionary?

For 2 characters[[2]](#2):

````
printf "%s\n" {0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}{0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z} > ./2-characters.txt
````

For 4 characters[[3]](#3)[[4]](#4):

````
echo {a..z}{a..z}{a..z}{a..z} | tr ' ' '\n' > ./4-characters.txt
````


### How to generate `easy-to-remember` dictionaries from the full dictionary?

````
grep '\(.\).*\1' 3-characters_AAA-ZZZ.txt > ./3-characters_easy-to-remember_AAA-ZZZ.txt
````

````
grep '\(.\).*\1.*\1' 4-characters_AAAA-ZZZZ.txt > ./4-characters_easy-to-remember_AAAA-ZZZZ.txt
````

This will extract usernames that have the same letter repeated multiple times, like `aaa`, `aab`, `aba`...[[5]](#5)


### How can I exclude those `easy-to-remember` usernames from the full dictionary?

````
comm -23 ./dictionary.txt ./easy-to-remember.txt > ./easy-to-remember-excluded.txt
````

[[6]](#6)


### Why are some checked out usernames unavailable?

GitHub may for some reason keep some usernames that are not open for registration, such as `47`, `fr`, `ccc`, although I found a lot of 2-character and 3-character usernames when I tried to register, but they were not available, but that doesn't mean you shouldn't try those 2 and 3-character usernames, because at any time a user could delete their account or change their username, so you might have better luck than me.


### How to check GitHub API remaining available requests?

````
curl -i -u "$USER:$TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit
````

[[7]](#7)


### Is it possible to use it under Windows?

It should work fine with [WSL](https://docs.microsoft.com/en-us/windows/wsl/install) and some 3rd party Linux tools ([Cygwin](https://github.com/cygwin/cygwin) or [Git bash](https://github.com/git-for-windows/git)).


### How do I find my current username?

1. In the GitHub Desktop menu, click Preferences.

2. In the Preferences window, verify the following:

     - To view your GitHub username, click Accounts. [[8]](#8)


### Is further support available?

No, I'm not going to use my time to continue developing and contributing to this repository, it's just a sharing of some experiences, if you're interested you can create something better!



## References

<a id="1">[1]</a> 
https://docs.github.com/en/rest/overview/resources-in-the-rest-api


<a id="2">[2]</a> 
https://stackoverflow.com/questions/57446583/find-all-combinations-of-two-character-letters-digits-similar-to-jot1-for-num/57446814#57446814


<a id="3">[3]</a> 
https://stackoverflow.com/questions/24279726/iterate-over-letters-in-a-for-loop/24279801#24279801


<a id="4">[4]</a> 
https://askubuntu.com/questions/461144/how-to-replace-spaces-with-newlines-enter-in-a-text-file/461153#461153


<a id="5">[5]</a> 
https://stackoverflow.com/questions/14223350/find-lines-in-file-that-contain-duplicate-characters/14223686#14223686


<a id="6">[6]</a> 
https://askubuntu.com/questions/461144/how-to-replace-spaces-with-newlines-enter-in-a-text-file/461153#461153


<a id="7">[7]</a> 
https://docs.github.com/en/rest/reference/rate-limit


<a id="8">[8]</a> 
https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-user-account/managing-email-preferences/remembering-your-github-username-or-email



## License

[![CC0](https://licensebuttons.net/p/zero/1.0/88x31.png)](https://creativecommons.org/publicdomain/zero/1.0/)
