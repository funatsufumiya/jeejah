;;; monroe-lua-complete.el --- Completion for Lua over Monroe connection

;; Copyright © 2016 Phil Hagelberg
;;
;; Author: Phil Hagelberg
;; URL: https://gitlab.com/technomancy/jeejah
;; Version: 0.1.0
;; Keywords: languages, nrepl, lua

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides live completion results for Lua by querying a Lua process
;; over an nREPL connection. Uses `completion-at-point' but can be
;; adapted for other completion methods.

;;; Installation:

;; Copy it to your load-path and (require 'monroe-lua-complete)

;;; Usage:

;; * Launch an nREPL server using jeejah.
;; * Connect to it with M-x monroe.
;; * Complete the expression at point with M-x completion-at-point
;;   also bound to M-tab or C-M-i.

;;; Code:

(require 'lua-mode) ; requires a newer lua-mode that has lua-start-of-expr
(require 'monroe)

(defvar monroe-completion-candidates nil)

(defun monroe-completion-handler (response)
  "Set `monroe-completion-candidates' based on response from Lua server.

Since monroe doesn't have any synchronous communication available, we
have to `sit-for' and hope a response has been returned and handled."
  (monroe-dbind-response response (id completions status output)
       (let ((process (get-buffer-process monroe-repl-buffer)))
         (comint-output-filter process output)
         (when completions
           (setq monroe-completion-candidates completions))
         (when status
           (when (member "done" status)
             (remhash id monroe-requests))))))

(defun monroe-lua-complete-function ()
  "Completion function for `completion-at-point-functions'.

Queries over current lua connection for possible completions."
  (let ((expr (buffer-substring-no-properties (lua-start-of-expr) (point))))
    (monroe-send-request `("op" "complete"
                           "input" ,expr
                           ;; TODO: at this time, monroe cannot bencode
                           ;; nested values, only string->string dicts
                           ;; "libs" ,(lua-local-libs)
                           "session" ,(monroe-current-session))
                         'monroe-completion-handler))
  (sit-for 0.1)
  (list (save-excursion (when (symbol-at-point) (backward-sexp)) (point))
        (point)
        monroe-completion-candidates))

;;;###autoload
(defun monroe-lua-hook ()
  (make-local-variable 'completion-at-point-functions)
  (add-to-list 'completion-at-point-functions 'monroe-lua-complete-function))

;;;###autoload
(eval-after-load 'lua-mode
  '(add-to-list 'lua-mode-hook 'monroe-lua-hook))

;;; monroe-lua-complete.el ends here
