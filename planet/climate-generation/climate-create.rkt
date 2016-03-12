#lang typed/racket

(provide static-climate
         climate-next
         climate-parameters/kw
         default-climate-parameters
         default-wind)

(require math/flonum
         vraid/typed-array
         "../grid.rkt"
         "../geometry.rkt"
         "../water.rkt"
         "../climate.rkt"
         "../terrain-generation/planet-create.rkt"
         "climate-create-base.rkt"
         "../terrain-generation/river-generation.rkt")

(: static-climate (climate-parameters planet-water -> ((Option planet-climate) -> planet-climate)))
(define (static-climate param planet)
  (let* ([planet/rivers (planet/rivers planet)]
         [season-count (climate-parameters-seasons-per-cycle param)]
         [initial ((climate/closed-season param planet/rivers) 0)]
         [v (build-vector season-count
                          (lambda ([n : Integer])
                            (delay (let ([p ((climate/closed-season param planet/rivers) n)])
                                     (generate-climate! param initial p)
                                     p))))])
    (lambda ([planet : (Option planet-climate)])
      (let ([season (if planet
                        (modulo (+ 1 (planet-climate-season planet))
                                season-count)
                        0)])
        (force (vector-ref v season))))))

(: climate/closed-season (climate-parameters planet-water -> (Integer -> planet-climate)))
(define ((climate/closed-season par planet) season)
  (let ([p (planet-climate/kw
            #:planet-water planet
            #:parameters par
            #:season season
            #:tile (make-tile-climate-data (tile-count planet))
            #:corner (make-corner-climate-data (corner-count planet))
            #:edge (make-edge-climate-data (edge-count planet)))])
    (let ([init-tile-array (tile-init p)])
      (init-tile-array (tile-climate-data-sunlight-set! (planet-climate-tile p))
                       (lambda ([n : Integer])
                         (sunlight
                          (planet-solar-equator p)
                          (tile-latitude p n))))
      (init-tile-array (tile-climate-data-temperature-set! (planet-climate-tile p))
                       (curry default-temperature p))
      (init-tile-array (tile-climate-data-snow-set! (planet-climate-tile p))
                       (curry default-snow-cover p)))
    p))

(: climate-next (climate-parameters planet-climate -> planet-climate))
(define (climate-next par prev)
  (let ([p (initial-values par prev)])
    (generate-climate! par prev p)
    p))

(struct: climate-data
  ([tile-humidity : FlVector]))

(: make-climate-data (planet-climate -> climate-data))
(define (make-climate-data p)
  (climate-data
   (make-flvector (tile-count p) 0.0)))

(: generate-climate! (climate-parameters planet-climate planet-climate -> Void))
(define (generate-climate! par prev p)
  (let* ([tile-water? (let ([v (build-vector (tile-count p)
                                             (lambda ([n : Integer])
                                               (tile-water? p n)))])
                        (lambda ([p : planet-climate]
                                 [n : Integer])
                          (vector-ref v n)))]
         [tile-land? (lambda ([p : planet-climate]
                              [n : Integer])
                       (not (tile-water? p n)))]
         [edge-lengths (build-flvector (edge-count p) (curry edge-length p))]
         [edge-length (lambda ([n : Integer])
                        (flvector-ref edge-lengths n))]
         [edge-tile-distances (build-flvector (edge-count p) (curry edge-tile-distance p))]
         [tile-tile-distance (lambda ([p : planet-climate]
                                      [n : Integer]
                                      [i : Integer])
                               (flvector-ref edge-tile-distances (tile-edge p n i)))])
    (define (climate-iterate!)
      (let* ([edge-wind (let ([winds (build-vector
                                      (edge-count p)
                                      (lambda ([n : Integer])
                                        (let ([scale (* ((edge-climate-data-air-flow (planet-climate-edge p)) n)
                                                        (edge-length n))])
                                          (wind
                                           (edge-tile p n (if (> 0.0 scale) 0 1))
                                           (abs scale)))))])
                          (lambda ([n : Integer])
                            (vector-ref winds n)))]
             [wind-list/filter (lambda ([f : (Integer Integer -> Boolean)])
                                 (let ([v (build-vector
                                           (tile-count p)
                                           (lambda ([n : Integer])
                                             (map edge-wind
                                                  (filter (curry f n)
                                                          (grid-tile-edge-list p n)))))])
                                   (lambda ([n : Integer])
                                     (vector-ref v n))))]
             [incoming-winds (wind-list/filter (lambda ([n : Integer]
                                                        [e : Integer])
                                                 (not (= n (wind-origin (edge-wind e))))))]
             [outgoing-winds (wind-list/filter (lambda ([n : Integer]
                                                        [e : Integer])
                                                 (= n (wind-origin (edge-wind e)))))]
             [total-wind (lambda ([ls : (Listof wind)])
                           (foldl + 0.0 (map wind-scale ls)))]
             [total-incoming-wind (lambda ([n : Integer])
                                    (total-wind (incoming-winds n)))]
             [total-outgoing-wind (lambda ([n : Integer])
                                    (total-wind (outgoing-winds n)))]
             [absolute-incoming-humidity (lambda ([tile-humidity : (Integer -> Float)]
                                                  [n : Integer])
                                           (for/fold: ([humidity : Float 0.0])
                                                      ([w (incoming-winds n)])
                                             (+ humidity
                                                (* (tile-humidity (wind-origin w))
                                                   (wind-scale w)))))])
        (: iterate! (climate-data climate-data Real -> climate-data))
        (define (iterate! to from delta)
          (if (< delta (climate-parameters-acceptable-delta par))
              from
              (let* ([set-tile-humidity! (lambda ([n : Integer]
                                                  [a : Float])
                                           (flvector-set! (climate-data-tile-humidity to) n a))]
                     [tile-humidity (lambda ([n : Integer])
                                      (flvector-ref (climate-data-tile-humidity from) n))])
                (for ([n (tile-count p)])
                  (set-tile-humidity! n (let ([saturation-humidity (saturation-humidity (tile-temperature p n))])
                                          (if (tile-water? p n)
                                              saturation-humidity
                                              (min saturation-humidity
                                                   (let ([outgoing (total-outgoing-wind n)])
                                                     (if (zero? outgoing)
                                                         saturation-humidity
                                                         (/ (absolute-incoming-humidity tile-humidity n)
                                                            outgoing))))))))
                (iterate! from to (apply max (map (lambda ([n : Integer])
                                                    (let ([current (flvector-ref (climate-data-tile-humidity to) n)]
                                                          [previous (flvector-ref (climate-data-tile-humidity from) n)])
                                                      (if (zero? current)
                                                          0.0
                                                          (if (zero? previous)
                                                              1.0
                                                              (flabs
                                                               (fl/ (fl- current
                                                                         previous)
                                                                    previous))))))
                                                  (range (tile-count p))))))))
        (let ([from (make-climate-data p)])
          (for ([n (tile-count p)])
            (flvector-set! (climate-data-tile-humidity from) n (if (tile-water? p n)
                                                                   (saturation-humidity (tile-temperature p n))
                                                                   0.0)))
          (let ([climate-values (iterate! (make-climate-data p)
                                          from
                                          1.0)])
            (for ([n (tile-count p)])
              ((tile-climate-data-humidity-set! (planet-climate-tile p)) n
                                                                         (flvector-ref (climate-data-tile-humidity climate-values) n)))
            (for ([n (tile-count p)])
              ((tile-climate-data-precipitation-set! (planet-climate-tile p)) n
                                                                              (let ([outgoing (* (tile-humidity p n)
                                                                                                 (total-outgoing-wind n))]
                                                                                    [incoming (absolute-incoming-humidity (curry tile-humidity p) n)])
                                                                                (max 0.0 (/ (* 200.0 (- incoming outgoing))
                                                                                            (tile-area p n))))))))))
    (set-wind! p)
    (climate-iterate!)
    (set-river-flow! p)
    (void)))

(: initial-values (climate-parameters planet-climate -> planet-climate))
(define (initial-values par prev)
  (let* ([p (struct-copy planet-climate prev
                         [season (modulo (+ 1 (planet-climate-season prev))
                                         (climate-parameters-seasons-per-cycle par))]
                         [tile (make-tile-climate-data (tile-count prev))]
                         [edge (make-edge-climate-data (edge-count prev))])]
         [init-tile-array (init-array (tile-count p))]
         [tile (planet-climate-tile p)])
    (init-tile-array (tile-climate-data-sunlight-set! tile)
                     (lambda ([n : Integer])
                       (sunlight
                        (planet-solar-equator p)
                        (tile-latitude p n))))
    (init-tile-array (tile-climate-data-temperature-set! tile)
                     (curry default-temperature p))
    (init-tile-array (tile-climate-data-snow-set! tile)
                     (curry default-snow-cover p))
    p))