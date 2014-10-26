#lang typed/racket

(provide (all-defined-out))

(require "../planet-structs.rkt"
         "time.rkt"
         vraid/math
         math/flonum)

(: planet-angular-velocity (planet -> Flonum))
(define (planet-angular-velocity p)
  (/ tau (planet-rotation-period p)))

(: planet-rotation-period (planet -> Flonum))
(define (planet-rotation-period p)
  (fl seconds-per-day))