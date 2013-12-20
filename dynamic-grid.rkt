#lang typed/racket

(provide (all-defined-out)
         (all-from-out "dynamic-grid-structs.rkt"
                       "dynamic-grid-access.rkt"))

(require "dynamic-grid-structs.rkt"
         "dynamic-grid-access.rkt"
         "vector3.rkt"
         math/flonum)

(define icosahedron-coordinates
  (let* ([x 0.525731112119133606]
         [z 0.850650808352039932]
         [-x (- x)]
         [-z (- z)])
    (vector
     (flvector x 0.0 -z)
     (flvector -x 0.0 -z)
     (flvector x 0.0 z)
     (flvector -x 0.0 z)
     (flvector 0.0 -z -x)
     (flvector 0.0 -z x)
     (flvector 0.0 z -x)
     (flvector 0.0 z x)
     (flvector -z -x 0.0)
     (flvector z -x 0.0)
     (flvector -z x 0.0)
     (flvector z x 0.0))))

(: icosahedron-tiles (Vectorof (Vectorof Integer)))
(define icosahedron-tiles
  (vector
   (vector 1 6 11 9 4)
   (vector 0 4 8 10 6)
   (vector 3 5 9 11 7)
   (vector 2 7 10 8 5)
   (vector 0 9 5 8 1)
   (vector 2 3 8 4 9)
   (vector 0 1 10 7 11)
   (vector 2 11 6 10 3)
   (vector 1 4 5 3 10)
   (vector 0 11 2 5 4)
   (vector 1 8 3 7 6)
   (vector 0 6 7 2 9)))

(: connect-corners (tile maybe-corner maybe-corner -> Void))
(define (connect-corners t a b)
  (begin
    (unless (not a)
      (let ([i (corner-tile-index a t)])
        (vector-set! (corner-corners a) i
                     b))))
  (unless (not b)
    (let ([i (corner-tile-index b t)])
      (vector-set! (corner-corners b) (corner-index b (+ i 1))
                   a))))

(: add-corner (tile tile tile -> corner))
(define (add-corner a b c)
  (let ([n (corner
            (flvector3-normal
             (apply flvector3+ (map (lambda: ([t : tile])
                                      (tile-coordinates t))
                                    (list a b c))))
            (vector a b c)
            (make-vector 3 false))])
    (begin
      (: connect (tile corner -> Void))
      (define (connect t c)
        (connect-corners t c (tile-corner t (tile-index t (+ 1 (tile-corner-index t c))))))
      
      (vector-set! (tile-corners a) (tile-tile-index a c) n)
      (vector-set! (tile-corners b) (tile-tile-index b a) n)
      (vector-set! (tile-corners c) (tile-tile-index c b) n)
      (connect a n)
      (connect b n)
      (connect c n)
      n)))

(: maybe->tile (maybe-tile -> tile))
(define (maybe->tile t)
  (if (not t)
      (tile false (flvector3-zero) (vector) (vector))
      t))

(: cornerize-top (tile -> Void))
(define (cornerize-top t)
  (for ([n (edge-count t)])
    (when (not (tile-corner t n))
      (add-corner t
                  (maybe->tile (tile-tile t (tile-index t (- n 1))))
                  (maybe->tile (tile-tile t n))))))
    
(: top-grid (Vectorof tile))
(define top-grid
  (let ([tiles (build-vector
                12
                (lambda: ([n : Integer])
                  (tile
                   false
                   (vector-ref icosahedron-coordinates n)
                   (vector)
                   (make-vector 5 false))))])
    (begin
      (for ([n 12])
        (set-tile-tiles!
         (vector-ref tiles n)
         (vector-map (lambda: ([k : Integer])
                       (vector-ref tiles k))
                     (vector-ref icosahedron-tiles n))))
      (for ([t tiles])
        (cornerize-top t))
      tiles)))

(: prune ((tile -> Boolean) tile -> tile))
(define (prune f t)
  t)

(: expand ((tile -> Boolean) tile -> tile))
(define (expand f t)
  t)