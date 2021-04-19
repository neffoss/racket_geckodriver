# racket_geckodriver
A Racket wrapper for Mozilla's gecko driver

You can find the GeckoDriver binary [here](https://github.com/mozilla/geckodriver/releases). [FireFox documention](https://firefox-source-docs.mozilla.org/testing/geckodriver/Usage.html) contains useful information on how to form the payload for the requests and working examples in CURL.

Currently using ver. 0.29.1.


## Running `geckodriver.rkt`
- First run `./racket_geckodriver/bin/geckodriver` to start listening at __127.0.0.1:4444__
- Then run `racket racket_geckdriver/geckodriver.rkt`
