(def cons (fn (a b) (. (. Array "[]" a) "+" (if b b (. Array "new")))))
(def concat (fn (a b) (. a "+" b)))

(def = (fn (a b) (. a "==" b)))
(def < (fn (a b) (. a "<" b)))
(def <= (fn (a b) (. a "<=" b)))
(def > (fn (a b) (. a ">" b)))
(def >= (fn (a b) (. a ">=" b)))

(def nil? (fn (a) (. a "nil?")))
(def throw (fn (a) (raise a)))

(def length (fn (a) (if a (. a "length") 0)))
(def empty? (fn (a) (= 0 (length a))))
(def list (fn (& args) args))
(def range (fn (first last) (. Range "new" first last)))
(def first (fn (a) (. a "first")))
(def rest (fn (a) (if (< (length a) 2) (list) (. a "[]" (range 1 -1)))))
(def last (fn (a) (. a "last")))

(defmacro and (fn (& args)
                   (if (empty? args)
                    true
                    (if (= 1 (length args))
                     (first args)
                     (quasiquote (if (unquote (first args))
                                    (and (splice_unquote (rest args)))
                                    (unquote (first args))))))))

(defmacro or (fn (& args)
                  (if (empty? args)
                   false
                   (if (= 1 (length args))
                    (first args)
                    (quasiquote (if (unquote (first args))
                                   (unquote (first args))
                                   (or (splice_unquote (rest args)))))))))

(def reduce (fn (f init coll)
                 (. coll "inject" (block f))))
(def filter (fn (pred a)
                 (if (empty? a)
                  nil
                  (if (pred (first a))
                   (cons (first a) (filter pred (rest a)))
                   (filter pred (rest a))))))

(def * (fn (& args)
            (or
             (reduce (fn (t n) (. t "*" n)) 1 args)
             1)))
(def / (fn (& args)
            (if (= 1 (length args))
             (. 1 "/" (. (first args) "to_f"))
             (. args "inject"
              (block (fn (t n) (. t "/" (. n "to_f"))))))))
(def + (fn (& args)
            (.
             (. args "inject"
              (block (fn (t n) (. t "+" n))))
             "to_i")))
(def - (fn (& args)
            (if (= 1 (length args))
             (* -1 (first args))
             (.
              (reduce (fn (t n) (. t "-" n)) 0 args)
              "to_i"))))

(def print (fn (a) (. Kernel "print" (. a "to_s"))))
(def println (fn (a) (print a) (print "\n")))
(defmacro not (fn (a) (if a false true)))
(defmacro unless (fn (pred t f) (quasiquote (if (unquote pred) (unquote f) (unquote t)))))
(def str (fn (& args)
              (if (empty? args)
               ""
               (.
                (. (first args) "to_s")
                "+"
                (apply str (rest args))))))
(def even? (fn (a) (. a "even?")))
(def odd? (fn (a) (. a "odd?")))

;(defmacro let (fn (binds & body)
       ;(def binds nil)
       ;(def vals nil)
       ;(:
       ;(if (empty? binds)
        ;(quasiquote (do (splice_unquote body)))

;)))

(defmacro assert
 (fn (pred message)
  (quasiquote (if (unquote pred)
                 (print ".")
                 (println
                  (str
                   "assertion failure "
                   (if (unquote message)
                    (unquote message)
                    (str "Expected " (. (unquote pred) "inspect") " to be truthy"))))))))
(defmacro assert=
 (fn (expected actual message)
  (quasiquote (if (= (unquote expected) (unquote actual))
                 (print ".")
                 (println
                  (str
                   "\n"
                   "assertion failure "
                   (if (unquote message)
                    (unquote message)
                    (str "Expected " (. (unquote expected) "inspect") " but got " (. (unquote actual) "inspect")))))))))