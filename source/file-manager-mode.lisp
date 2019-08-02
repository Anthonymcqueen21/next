;;; file-manager-mode.lisp -- Manage files.
;;;
;;; Open any file from within Next, with the usual fuzzy completion.
;;;
;;; `M-x open-file (C-x C-f)'
;;;
;;; "file manager" is a big excessive for now. Currently, we can:
;;; - browse files, with fuzzy-completion
;;; - go one directory up (C-l)
;;; - enter a directory (C-j)
;;; - open files. By default, with xdg-open. See `open-file-fn'.
;;;
;;; ***********************************************************************
;;; *disclaimer*: this feature is meant to grow with Next 1.4 and onwards !
;;; ***********************************************************************
;;;
;;; Much can be done:
;;; - configuration options to choose what to open with
;;; - more configuration in general
;;; - sort by last access, etc
;;; - multi-selection
;;; - open files in Next
;;; - a UI to list files
;;; - lazy loading for large directories
;;; - many things...
;;;

(in-package :next)

(defvar *current-directory* download-manager::*default-download-directory*
  "Default directory to open files from. Defaults to the downloads directory.")

(defun open-file-fn-default (filename)
  "Open this file with `xdg-open'."
  (handler-case (uiop:run-program (list "xdg-open" (namestring filename)))
    ;; We can probably signal something and display a notification.
    (error (c) (format *error-output* "Error opening ~a: ~a~&" filename c))))

;; TODO: Remove `open-file-fn` (it's just a one-liner) and instead store the
;; "open-file-function" into a download-mode slot, which is then called from
;; `download-open-file' with `(funcall (open-file-function download-mode)
;; filename).
(export 'open-file)  ;; the user is encouraged to override this in her init file.
(defun open-file-fn (filename)
  "Open this file. `filename' is the full path of the file (or directory), as a string.
By default, try to open it with the system's default external program, using `xdg-open'.
The user can override this function to decide what to do with the file."
  (open-file-fn-default filename))

(defun open-file-from-directory-completion-fn (input &optional (directory *current-directory*))
  "Fuzzy-match files and directories from `*current-directory*'."
  (let ((filenames (uiop:directory-files directory))
        (dirnames (uiop:subdirectories directory)))
    (fuzzy-match input (append filenames dirnames))))

(define-command display-parent-directory (minibuffer-mode &optional (minibuffer (minibuffer *interface*)))
  "Get the parent directory and update the minibuffer."
  (setf *current-directory* (cl-fad:pathname-parent-directory *current-directory*))
  (update-display minibuffer))

(define-command enter-directory (minibuffer-mode &optional (minibuffer (minibuffer *interface*)))
  "If the candidate at point is a directory, refresh the minibuffer candidates with its list of files.

Default keybinding: `C-j'. "
  (let ((filename (get-candidate minibuffer)))
    (when (and (cl-fad:directory-pathname-p filename)
               (cl-fad:directory-exists-p filename))
      (setf *current-directory* filename)
      (update-display minibuffer))))

(define-command open-file (root-mode &optional (interface *interface*))
  "Open a file from the filesystem.

The user is prompted with the minibuffer, files are browsable with the fuzzy completion.

The default directory is the one from `next/download-manager::*default-download-directory*' (which is `~/Downloads' by default).

Press `Enter' to visit a file, `C-l' to go one directory up, `C-j' to browse the directory at point.

By default, it uses the `xdg-open' command. The user can override the `next:open-file-fn' function, which takes the filename (or directory name) as parameter.

The default keybinding is `C-x C-f'.

Note: this feature is alpha, get in touch for more !"
  (let ((directory *current-directory*))
    (with-result (filename (read-from-minibuffer
                            (minibuffer interface)
                            :input-prompt (file-namestring directory)
                            :completion-function #'open-file-from-directory-completion-fn))

      (open-file-fn (namestring filename)))))


(define-key  "C-x C-f" #'open-file)

(define-key :mode 'minibuffer-mode  "C-l" #'display-parent-directory)
(define-key :mode 'minibuffer-mode  "C-j" #'enter-directory)
