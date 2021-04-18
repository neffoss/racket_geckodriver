#lang racket
(require net/url)
(require json)
(require net/http-client)

(define svr-url "127.0.0.1")
(define svr-port 4444)

; This is the hash with the basic capabilities to spin up a headless Firefox instance
(define basic-capabilities (hasheq 'capabilities (hasheq 'alwaysMatch (hasheq 'acceptInsecureCerts #t))))

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

(define (delete-session conn session-id)
  (define-values (status headers response)
    (http-conn-sendrecv! conn (string-append "/session/" session-id)
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


(define conn (connect-geckosvr svr-url svr-port))
(define session-id (get-session-id (new-session conn)))
(displayln session-id)
(navigate-to conn session-id "https://slashdot.org")
(delete-session conn session-id)
(http-conn-close! conn)
