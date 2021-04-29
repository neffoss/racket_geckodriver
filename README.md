# racket_geckodriver
A Racket wrapper for Mozilla's gecko driver

You can find the GeckoDriver binary [here](https://github.com/mozilla/geckodriver/releases). [FireFox documention](https://firefox-source-docs.mozilla.org/testing/geckodriver/Usage.html) contains useful information on how to form the payload for the requests and working examples in CURL.

Currently using ver. 0.29.1.


## Running `geckodriver.rkt`
- First run `./racket_geckodriver/bin/geckodriver` to start listening at __127.0.0.1:4444__
- Then run `racket racket_geckdriver/geckodriver.rkt`


## Functions

Implemented

- get-session-id
- connect-geckosvr
- new-session
- delete-session
- close-window
- navigate-to
- session-back
- find-elements
- click-elements
- execute-sync
- get-page-source

More functions will be implemented when they will be needed.

## Usage

    (define svr-url "127.0.0.1")
    (define svr-port 4444)

    (define conn (connect-geckosvr svr-url svr-port))
    (define session-id (get-session-id (new-session conn))) 

    (navigate-to conn session-id "https://efiling.drcor.mcit.gov.cy/DrcorPublic/SearchResults.aspx?name=%25&number=1&searchtype=optStartMatch&index=1&tname=%25&sc=0")

    (execute-sync conn session-id "document.getElementsByClassName('basket')[0].click();")
    (sleep 2)
    (get-page-source conn session-id)
