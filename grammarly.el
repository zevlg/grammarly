;;; grammarly.el --- Grammarly API interface.  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Shen, Jen-Chieh
;; Created date 2019-11-06 20:41:48

;; Author: Shen, Jen-Chieh <jcs090218@gmail.com>
;; Description: Grammarly API interface.
;; Keyword: grammar api interface english
;; Version: 0.0.1
;; Package-Requires: ((emacs "24.4") (cl-lib "0.6") (request "0.3.0") (websocket "1.6"))
;; URL: https://github.com/jcs090218/grammarly

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Grammarly API interface.
;;

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'request)
(require 'websocket)


(defgroup grammarly nil
  "Grammarly API interface."
  :prefix "grammarly-"
  :group 'tool
  :link '(url-link :tag "Github" "https://github.com/jcs090218/grammarly"))


(defconst grammarly--authorize-msg
  '(("origin" . "chrome-extension://kbfnbcaeplbcioakkpcpgfkobkghlhen")
    ("headers" . (("Cookie" . "$COOKIES$")
                  ("User-Agent" . "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:68.0) Gecko/20100101 Firefox/68.0"))))
  "Authorize message for Grammarly API.")

(defconst grammarly--init-msg
  '(("type" . "initial")
    ("token" . "null")
    ("docid" . "dfad0927-7b35-e155-6de9-4a107053da35-43543554345")
    ("client" . "extension_chrome")
    ("protocolVersion" . "1.0")
    ("clientSupports" . ("free_clarity_alerts"
                         "readability_check"
                         "filler_words_check"
                         "sentence_variety_check"
                         "free_occasional_premium_alerts"))
    ("dialect" . "american")
    ("clientVersion" . "14.924.2437")
    ("extDomain" . "editpad.org")
    ("action" . "start")
    ("id" . 0))
  "Grammarly initialize message for verify use.")

(defvar-local grammarly--client nil
  "Websocket for this client.")

(defvar-local grammarly--update-time 0.1
  "Run every this seconds until we received API request.")

(defvar-local grammarly--cookies ""
  "Record the cookie down.")

(defvar-local grammarly--timer nil
  "Universal timer for each await use.")


(defun grammarly--last-cookie (cookie cookies)
  "Check if current COOKIE the last cookie from COOKIES."
  (equal (nth (1- (length cookies)) cookies) cookie))

(defun grammarly--form-cookie ()
  "Form all cookies into one string."
  (let ((sec-cookies (request-cookie-alist ".grammarly.com" "/" t))
        (cookie-str ""))
    (dolist (cookie sec-cookies)
      (setq cookie-str
            (format "%s %s=%s%s" cookie-str (car cookie) (cdr cookie)
                    (if (grammarly--last-cookie cookie sec-cookies) "" ";"))))
    (string-trim cookie-str)))

(defun grammarly--get-cookie ()
  "Get cookie."
  (setq grammarly--cookies "")  ; Reset to clean string.
  (request
   "https://grammarly.com/"
   :type "GET"
   :success
   (cl-function
    (lambda (&key response  &allow-other-keys)
      (setq grammarly--cookies (grammarly--form-cookie))))
   :error
   ;; NOTE: Accept, error.
   (cl-function
    (lambda (&rest args &key _error-thrown &allow-other-keys)
      (user-error "[ERROR] Error while getting cookie")))))


(defun grammarly--form-authorize-list ()
  "Form the authorize list."
  (let ((auth (copy-sequence grammarly--authorize-msg)))
    ;; NOTE: Here we directly point to the `$COOKIES$' keyword.
    (setcdr (nth 0 (cdr (nth 1 auth))) grammarly--cookies)
    auth))

(defun grammarly--after-got-cookie ()
  "Execution after received all needed cookies."
  (grammarly--kill-websocket)
  (setq
   grammarly--client
   (websocket-open
    "wss://capi.grammarly.com/freews"
    :protocols
    (grammarly--form-authorize-list)
    :on-open
    (lambda (_ws)
      (websocket-send-text grammarly--client (json-encode grammarly--init-msg))
      (message "opened")
      )
    :on-message
    (lambda (_ws frame)
      (message "ws frame: %S" (websocket-frame-text frame))
      )
    :on-error
    (lambda (_ws _type err)
      (message "%s" (grammarly--form-authorize-list))
      (message "%s" (json-encode (grammarly--form-authorize-list)))
      (user-error "[ERROR] Connection error while opening websocket: %s" err))
    :on-close
    (lambda (_ws)
      (setq grammarly--client nil)))))

(defun grammarly--after-socket-opened ()
  "Execution after the socket is opened."
  )

(defun grammarly--kill-websocket ()
  "Kil the websocket."
  (when grammarly--client
    (websocket-close grammarly--client)
    (setq grammarly--client nil)))

(defun grammarly--kill-timer ()
  "Kill the timer."
  (when (timerp grammarly--timer)
    (cancel-timer grammarly--timer)
    (setq grammarly--timer nil)))

(defun grammarly--reset-timer (fnc pred)
  "Reset the timer for the next run with FNC and PRED."
  (grammarly--kill-timer)
  (if (funcall pred)
      (setq grammarly--timer
            (run-with-timer grammarly--update-time nil
                            'grammarly--reset-timer fnc pred))
    (funcall fnc)))

;;;###autoload
(defun grammarly-check-text (text)
  "Send the TEXT to check."
  (grammarly--get-cookie)
  (grammarly--reset-timer 'grammarly--after-got-cookie
                          #'(lambda () (string-empty-p grammarly--cookies)))
  )

(grammarly-check-text "Lets get started the work and please ensure all Ganoderma is collected before we leave.")


(provide 'grammarly)
;;; grammarly.el ends here