(local jeejah (require :jeejah))

(local help (string.format "jeejah %s" jeejah.version))

;; TODO: write .nrepl-port file?
(case ...
  "--help" (print help)
  n (case (tonumber n)
      port (jeejah.start {: port})
      _ (do (print help) (os.exit 1))))
