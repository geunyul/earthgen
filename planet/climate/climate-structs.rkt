#lang typed/racket

(provide (all-defined-out)
         (all-from-out "climate-data-structs.rkt"))

(require vraid/struct
         vraid/math
         math/flonum
         "../water.rkt"
         "climate-data-structs.rkt"
         "../direct-access.rkt")

(struct/kw: climate-parameters
            ([axial-tilt : Float]
             [seasons-per-cycle : Positive-Integer]
             [acceptable-delta : Float])
            #:transparent)

(: default-climate-parameters (-> climate-parameters))
(define (default-climate-parameters)
  (climate-parameters/kw
   #:acceptable-delta 0.01
   #:axial-tilt (/ pi 8.0)
   #:seasons-per-cycle 16))

(: planet-time-of-year (planet-climate -> Float))
(define (planet-time-of-year planet)
  (fl (/ (planet-climate-season planet)
         (climate-parameters-seasons-per-cycle (planet-climate-parameters planet)))))

(: planet-solar-equator (planet-climate -> Float))
(define (planet-solar-equator planet)
  (* (sin (* tau (planet-time-of-year planet)))
     (climate-parameters-axial-tilt (planet-climate-parameters planet))))

(struct/kw: planet-climate planet-water
            ([parameters : climate-parameters]
             [season : Integer]
             [tile : tile-climate-data]
             [corner : corner-climate-data]
             [edge : edge-climate-data]))

(direct-access planet-climate tile tile-climate-data
               ([snow Float]
                [sunlight Float]
                [temperature Float]
                [humidity Float]
                [precipitation Float]))

(direct-access planet-climate corner corner-climate-data
               ([river-flow Float]))

(direct-access planet-climate edge edge-climate-data
               ([river-flow Float]
                [air-flow Float]))