#lang racket

; https://docs.racket-lang.org/guide/module-basics.html#%28part._.Library_.Collections%29
; require is looking implicitily for main.rkt to shorten the declaration of the import
(require "geckodriver.rkt")
(provide (all-from-out "geckodriver.rkt"))
