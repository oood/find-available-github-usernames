# :octocat: find available github username

## 📜 Table of Contents

- [Usage](#usage)
  - [v1 script](#v1-script)
  - [v2 script](#v2-script)
  - [Combining both versions](#combining-both-versions)
- [Project Background](#project-background)
- [FAQs](#faqs)
  - [Dictionary file name meaning?](#dictionary-file-name-meaning)
  - [What is the difference between full dictionary and `easy-to-remember`?](#what-is-the-difference-between-full-dictionary-and-easy-to-remember)
  - [How do I generate a dictionary?](#how-do-i-generate-a-dictionary)
  - [How to generate `easy-to-remember` dictionaries from the full dictionary?](#how-to-generate-easy-to-remember-dictionaries-from-the-full-dictionary)
  - [How can I exclude those `easy-to-remember` usernames from the full dictionary?](#how-can-i-exclude-those-easy-to-remember-usernames-from-the-full-dictionary)
  - [Why are some usernames unavailable checked via `v1.sh`](#why-are-some-usernames-unavailable-checked-via-v1sh)
  - [How to check GitHub API remaining available requests?](#how-to-check-github-api-remaining-available-requests)
  - [Is it possible to use it under Windows?](#is-it-possible-to-use-it-under-windows)
  - [How do I find my current username?](#how-do-i-find-my-current-username)
  - [Is further support available?](#is-further-support-available)
- [License](#license)

## Usage

Clone the repository

```sh
git clone https://github.com/oood/find-available-github-usernames.git && cd find-available-github-usernames
```

### v1 script

---

|Conditions|Requests per Hour|
|-|-|
|Username only|60|
|Username and token|5000|

---

1) **Generate a Personal Access Token**:
   - Register on GitHub and go to `Settings > Developer Settings > Personal Access Token` to create your token.
  
2) Edit the script and fill in your current GitHub username and token

```sh
USER="" # your_current_username
TOKEN="" # your_api_token
```

3) Run script

````sh
./v1.sh <path to dictionary.txt> <threads>
````

**To stop script, just press ```^C (Ctrl+C)``` or wait until it stops**

**To get information about api limits:**

````sh
./v1.sh --api
````

Response example:

```sh
> ./v1.sh --api
TOKEN is empty
Limit: 60
Used: 46
Remaining: 14
Reset time: 2024-10-21 20:11:20
```

**Notes:**


The working principle of the script is very simple, import the first line of the dictionary, check whether the username is available, if got `HTTP: 404`, add it to the `v1_found.txt`, if encounter an error, print and output to the `v1.log`, and finally delete all checked lines in the dictionary.


The reason for deleting the lines in the dictionary is to ensure that the task can be terminated at any time by pressing `^c` (Ctrl+C) in the terminal and don't have to start from the beginning on the next run.


The first time the script is run, a backup file with a `.bak` suffix is generated for the dictionary.

### v2 script

---

~4200-6000 Requests Per Hour

---

1) Find tokens from GitHub web version.
    - Go to `Settings` > `Account` > `Change username`
    - Open `Web DevTools` > `Network`
    - Type something in `Choose a new username form`
    - Click on `rename_check?suggest_usernames=true` in `Web DevTools`
    - Look at Headers and Payload
  
2) Edit the script and fill in your current tokens

```sh
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
```

3) Run script

````sh
./v2.sh <path to dictionary.txt> <threads>
````

GitHub allows you to make 70-100 requests per minute so you can run:

```sh
./auto-v2.sh <path to dictionary.txt>
```

it just runs `v2.sh` every minute with 100 threads

**To stop script, just press ```^C (Ctrl+C)``` or wait until it stops**

### Combining both versions

Use `v1.sh` and after what `auto-v2.sh` with result of `v1.sh`

```sh
./v1 dictionaries/4-characters_easy-to-remember_AAAA-ZZZZ.txt 100
```

And next

```sh
./auto-v2.sh v1_found.txt
```

result will be in `v2_found.txt`

---

## Project Background

GitHub allows everyone to check user pages, I initially wrote a script and created some dictionaries with character combinations to check all URLs `https://github.com/$username`. this worked fine at first, but unfortunately after a few minutes I triggered an `Error: 429 Too many requests`, so I started searching to see if there was a better way, and I found that GitHub provides an API that can be used to retrieve registered username and available username, but I don't have an account how can I get an API token?


There are two ways: First, register an account with any username, then get the API token and then find the appropriate username and modify it. Or bypass the restriction with proxies :shipit:, which I know is rude, so I chose the first way.


GitHub serves 5,000 requests per hour for users using the API, which seems a bit low considering the short usernames that are still available from millions of usernames, but compared to only 60 requests per IP per hour without the API, that's a huge difference.


I generated the 2-character dictionary and found some "available" usernames, but I found out that they were just reserved usernames, then I tried the 3-character dictionary again, this time I didn't intend to check all 3-characters, because I didn't want to wait too long, and all combinations were already well over the limit of 5,000 per hour, I generated `easy-to-remember` dictionaries from all combinations, then I didn't find a username that worked for me, and finally I found my current username in a 4-character `easy-to-remember` dictionary.

## FAQs

### Dictionary file name meaning?

---

`2-characters_00-99_AA-ZZ.txt` Consists of 2 characters, including all combinations of letters and digits.

`3-characters_AAA-ZZZ.txt` and `4-characters_AAAA-ZZZZ.txt` Contains all combinations of all 3 and 4 letters, no digits.

`XX-characters_easy-to-remember_XX.txt` Usernames with repeated characters.

### What is the difference between full dictionary and `easy-to-remember`?

---

I recommend trying the `easy-to-remember` ones in my dictionaries first, as those that have some kind of regularity, like multiple occurrences of the same character, and easier to type. other dictionaries are full dictionaries, which means they may contain thousands of usernames.

### How do I generate a dictionary?

---

For 2 characters:

```sh
printf "%s\n" {0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}{0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z} > ./2-characters.txt
```

For 4 characters:

```sh
echo {a..z}{a..z}{a..z}{a..z} | tr ' ' '\n' > ./4-characters.txt
```

### How to generate `easy-to-remember` dictionaries from the full dictionary?

---

```sh
grep '\(.\).*\1' 3-characters_AAA-ZZZ.txt > ./3-characters_easy-to-remember_AAA-ZZZ.txt
```

```sh
grep '\(.\).*\1.*\1' 4-characters_AAAA-ZZZZ.txt > ./4-characters_easy-to-remember_AAAA-ZZZZ.txt
```

This will extract usernames that have the same letter repeated multiple times, like `aaa`, `aab`, `aba`...

### How can I exclude those `easy-to-remember` usernames from the full dictionary?

---

```sh
comm -23 ./dictionary.txt ./easy-to-remember.txt > ./easy-to-remember-excluded.txt
```

### Why are some usernames unavailable checked via `v1.sh`?

---

GitHub may for some reason keep some usernames that are not open for registration, such as `47`, `fr`, `ccc`, although I found a lot of 2-character and 3-character usernames when I tried to register, but they were not available, but that doesn't mean you shouldn't try those 2 and 3-character usernames, because at any time a user could delete their account or change their username, so you might have better luck than me.

The `v2.sh` script utilizes the  `https://github.com/account/rename_check` endpoint to verify the availability of these usernames.

### How to check GitHub API remaining available requests?

---

```sh
./v1.sh --api
```

or

```sh
curl -i -u "$USER:$TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit
```

### Is it possible to use it under Windows?

---

It should work fine with [WSL](https://docs.microsoft.com/en-us/windows/wsl/install) and some 3rd party Linux tools ([Cygwin](https://github.com/cygwin/cygwin) or [Git bash](https://github.com/git-for-windows/git)).

### How do I find my current username?

---

1. In the GitHub Desktop menu, click Preferences.

2. In the Preferences window, verify the following:
    - To view your GitHub username, click Accounts.

### Is further support available?

---

No, I'm not going to use my time to continue developing and contributing to this repository, it's just a sharing of some experiences, if you're interested you can create something better!

## License

This project is available under the [Creative Commons Zero (CC0) License](LICENSE), allowing anyone to use, modify, and distribute the work without restrictions.

[![CC0](https://licensebuttons.net/p/zero/1.0/88x31.png)](https://creativecommons.org/publicdomain/zero/1.0/)
