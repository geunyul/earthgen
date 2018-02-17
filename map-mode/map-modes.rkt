#lang typed/racket

(require "map-mode.rkt"
         "planet-color.rkt"
         "../planet/terrain-base.rkt"
         "../planet/climate-base.rkt")

(provide (all-defined-out))

(define-map-modes terrain planet-terrain?
  (topography color-topography))

(define-map-modes climate planet-climate?
  (landscape color-landscape)
  (vegetation color-leaf-area-index)
  (temperature color-temperature)
  (insolation color-insolation)
  (aridity color-aridity)
  (humidity color-humidity)
  (precipitation color-precipitation))