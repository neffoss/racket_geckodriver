#lang racket

(provide connect-geckosvr)
(provide new-session)
(provide get-session-id)
(provide navigate-to)
(provide execute-sync)
(provide session-back)
(provide delete-session)
(provide close-window)

(require net/url
         json
         net/http-client
         html-parsing
         sxml/sxpath)

; This is the hash with the basic capabilities to spin up a headless Firefox instance
(define basic-capabilities (hasheq 'capabilities (hasheq 'alwaysMatch (hasheq 'acceptInsecureCerts #t))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: get-session-id
;;;
;;;  Description: Extracts the browser session ID from Web Driver, from a
;;;               new session. In the page below are the details:
;;;               https://w3c.github.io/webdriver/#dfn-new-sessions
;;;
;;;  Input parameters
;;;
;;;    url: The JSON response returned from the New Session endpoint.
;;;
;;;  Return value: The session ID assigned to the newly created browser session.
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (get-session-id json-res)
  (hash? . -> . string?)
  ;{"value":{"sessionId":"a01f5999-b630-6d42-8ef4-14b9cf64ac7f","capabilities":....
  (hash-ref (hash-ref (string->jsexpr json-res) 'value) 'sessionId))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: connect-geckosvr
;;;
;;;  Description: Connects to an already running Gecko server. 
;;;
;;;  Input parameters
;;;
;;;    host: The hostname of the box running the Gecko server.
;;;    port: The port to connect.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (connect-geckosvr host port)
  (string? string? . -> . string?)
  (http-conn-open host
                  #:ssl? #f
                  #:port port
                  #:auto-reconnect? #t))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: new-session
;;;
;;;  Description: Starts a new browser session and launched a headless Firefox
;;;               instance.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;
;;;  Return value: A JSON containing the session details, currently we are only
;;;                interested in the session ID, which you can get with
;;;
;;;                (get-session-id (new-session conn))
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (new-session conn)
  (string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn "/session"
                   #:method "POST"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: delete-session
;;;
;;;  Description: Deletes the session in the Gecko server.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;
;;;  Return value: A JSON containing the session details, currently we are only
;;;                interested in the session ID, which you can get with
;;;
;;;  Note: No need to call it if close-window is called.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (delete-session conn session-id)
  (string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id)
                   #:method "DELETE"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: close-window
;;;
;;;  Description: Closes the headless browser window and terminates the session.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (close-window conn session-id)
  (string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/window")
                   #:method "DELETE"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: navigate-to
;;;
;;;  Description: Points the browser to the given URL.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;    url: The URL of the page to load.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (navigate-to conn session-id url)
  (string? string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/url")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'url url))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: session-back
;;;
;;;  Description: Points the browser to the previous page in the browser history.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;  Note: Simply the equivalent of pressing the "Back" button.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (session-back conn session-id )
  (string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/back")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: find-elements
;;;
;;;  Description: Find the page elements whose CSS elements match the CSS
;;;               selector given.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;    css-selector: A CSS class or CSS id to select page elements.
;;;
;;;  Return value: A list containing hashes with the structure
;;;
;;;                ({ session-id: element-id } { session-id: element-id } ...)
;;;
;;;  Note: You can get the element IDs with (map (lambda (e) (first (hash-values e))) elements))
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (find-elements conn session-id css-selector)
  (string? string? string? . -> . string?)  
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/elements")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'using "css selector" 'value css-selector))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: click-elements
;;;
;;;  Description: Clicks the element with the given element-id.
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;    element-id: The element ID of the element to click.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (click-element conn session-id element-id)
  (string? string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/element/" element-id "/click")
                   #:method "POST"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: execute-sync
;;;
;;;  Description: Execute synchronously the given Javascript code
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;    js-script: The script to be executed
;;;
;;;  Return value: The page's source code as a X-expression.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (execute-sync conn session-id js-script)
  (string? string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/execute/sync")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'script js-script 'args '()))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Name: get-page-source
;;;
;;;  Description: Returns the page source 
;;;
;;;  Input parameters
;;;
;;;    conn: The connection reference.
;;;    session-id: The session ID.
;;;
;;;  Return value: "{\"value\":[]}" in case the call concluded successfuly or
;;;                an errr message if it didn't.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (get-page-source conn session-id )
  (string? string? . -> . string?)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/source")
                   #:method "GET"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  ; There are a lot of conversions below, port to string, then hash and then
  ; picking the value of the 'value' key which is the page source
  ; finally the string is HTML string is parsed to a X-expression 
  (html->xexp (hash-ref (string->jsexpr (port->string response)) 'value)))



; Move below to a module for eFilling scrapper
(define (get-tbl-values tag select-fun tbl-row)
  (map select-fun ((sxpath (string-append "//" tag )) tbl-row)))

(define (parse-xpath-table tbl)
  (if (empty? tbl)
      '()
      (let* ([rows ((sxpath "//tr") tbl)]
             [hdr (first rows)]
             [data-rows (rest rows)])
        (list (get-tbl-values "th" last hdr )
              (for/list ([row data-rows]) (get-tbl-values "td" rest row))))))




; Parses the list of hashes and returns only the element IDs
; The initial structure looks like
;    hashed('value . (<session-id> . <element-id>) (<session-id> . <element-id>) ...)
;
; Return: A list of element-IDs
(define (parse-companies-table table-hash)
  (let ([elements (hash-ref table-hash 'value)])
    (map (lambda (e) (first (hash-values e))) elements)))

(define svr-url "127.0.0.1")
(define svr-port 4444)

; The eFilling scrapper logic, needs to be moved to a separate scrapper app.
(define conn (connect-geckosvr svr-url svr-port))
(define session-id (get-session-id (new-session conn)))
(navigate-to conn session-id "https://efiling.drcor.mcit.gov.cy/DrcorPublic/SearchResults.aspx?name=%25&number=1&searchtype=optStartMatch&index=1&tname=%25&sc=0")

;(define rows-count (length (parse-companies-table  (find-elements conn session-id ".basket" 0))))

(execute-sync conn session-id "document.getElementsByClassName('basket')[0].click();")
(sleep 2)

(define table ((sxpath "//table[contains(@id, 'tbDetSummary')]") (get-page-source conn session-id)))
(define parsed-table (second (parse-xpath-table table)))
parsed-table
;(first (second parsed-table))

;(sleep 2)
;(session-back conn session-id)
;(sleep 2)


;(execute-sync conn session-id "document.getElementsByClassName('basket')[1].click();")
;(sleep 2)
;((sxpath "//table[contains(@id, 'tbDetSummary')]") (get-page-source conn session-id))
;(sleep 2)
;(session-back conn session-id)
;(sleep 2)


;(execute-sync conn session-id "document.getElementsByClassName('basket')[2].click();")
;(sleep 2)
;((sxpath "//table[contains(@id, 'tbDetSummary')]") (get-page-source conn session-id))
;(sleep 2)
;(session-back conn session-id)
;(sleep 2)

(close-window conn session-id)
(http-conn-close! conn)
