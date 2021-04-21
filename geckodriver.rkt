#lang racket
(require net/url)
(require json)
(require net/http-client)

(define svr-url "127.0.0.1")
(define svr-port 4444)

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
;;;    url: The URL to fetch.
;;;
;;;  Return value: The page's code as X-expression.
;;;
;;;  note: Nice read on X-expressions https://xy2.dev/article/racket-blog/
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (get-session-id json-res)
  ;{"value":{"sessionId":"a01f5999-b630-6d42-8ef4-14b9cf64ac7f","capabilities":....
  (hash-ref (hash-ref (string->jsexpr json-res) 'value) 'sessionId))

(define (connect-geckosvr host port)
  (http-conn-open host
                  #:ssl? #f
                  #:port port
                  #:auto-reconnect? #t))

(define (new-session conn)
  (define-values (status headers response)
    (http-conn-sendrecv! conn "/session"
                   #:method "POST"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))

; No need to call it if close-window is called.
(define (delete-session conn session-id)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id)
                   #:method "DELETE"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


(define (close-window conn session-id)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/window")
                   #:method "DELETE"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


(define (navigate-to conn session-id url)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/url")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'url url))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


(define (session-back conn session-id url)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/back")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'url url))
                   #:headers (list "Content-Type: application/json")))
  (port->string response))


(define (find-elements conn session-id css-selector)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/elements")
                   #:method "POST"
                   #:data (jsexpr->string (hasheq 'using "css selector" 'value css-selector))
                   #:headers (list "Content-Type: application/json")))
  (string->jsexpr (port->string response)))


(define (click-element conn session-id element-id)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id "/element/" element-id "/click")
                   #:method "GET"
                   #:data (jsexpr->string basic-capabilities)
                   #:headers (list "Content-Type: application/json")))
  (port->string response))

; Move below to a module for eFilling scrapper

; Parses the list of hashes and returns only the element IDs
; The initial structure looks like
;    hashed('value . (<session-id> . <element-id>) (<session-id> . <element-id>) ...)
;
; Return: A list of element-IDs
(define (parse-companies-table table-hash)
  (let ([elements (hash-ref table-hash 'value)])
    (map (lambda (e) (first (hash-values e))) elements)))


; The eFilling scrapper logic, needs to be moved to a separate scrapper app.
(define conn (connect-geckosvr svr-url svr-port))
(define session-id (get-session-id (new-session conn)))
(displayln session-id)
(sleep 2)
(navigate-to conn session-id "https://efiling.drcor.mcit.gov.cy/DrcorPublic/SearchResults.aspx?name=%25&number=1&searchtype=optStartMatch&index=1&tname=%25&sc=0")
(sleep 2)


(define elem-ids (append
 (parse-companies-table  (find-elements conn session-id ".basket"))
 (parse-companies-table  (find-elements conn session-id ".basketAlternateRow"))))
elem-ids

(click-element conn session-id (first elem-ids))

(close-window conn session-id)
(http-conn-close! conn)
