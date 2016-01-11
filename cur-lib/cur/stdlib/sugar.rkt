#lang s-exp "../cur.rkt"
(provide
  ->
  ->*
  forall*
  lambda*
  (rename-out
    [-> →]
    [->* →*]
    [lambda* λ*]
    [forall* ∀*])
  #%app
  define
  elim
  define-type
  case
  case*
  match
  recur
  let

  ;; type-check
  ::

  ;; reflection in syntax
  run
  step
  step-n
  query-type)

(require
  (only-in "../cur.rkt"
    [elim real-elim]
    [#%app real-app]
    [define real-define]))

(define-syntax (-> syn)
  (syntax-case syn ()
    [(_ t1 t2) #`(forall (#,(gensym) : t1) t2)]))

(define-syntax ->*
  (syntax-rules ()
    [(->* a) a]
    [(->* a a* ...)
     (-> a (->* a* ...))]))

(define-syntax forall*
  (syntax-rules (:)
    [(_ (a : t) (ar : tr) ... b)
     (forall (a : t)
        (forall* (ar : tr) ... b))]
    [(_ b) b]))

(define-syntax lambda*
  (syntax-rules (:)
    [(_ (a : t) (ar : tr) ... b)
     (lambda (a : t)
       (lambda* (ar : tr) ... b))]
    [(_ b) b]))

(define-syntax (#%app syn)
  (syntax-case syn ()
    [(_ e) #'e]
    [(_ e1 e2)
     #'(real-app e1 e2)]
    [(_ e1 e2 e3 ...)
     #'(#%app (#%app e1 e2) e3 ...)]))

(define-syntax define-type
  (syntax-rules ()
    [(_ (name (a : t) ...) body)
     (define name (forall* (a : t) ... body))]
    [(_ name type)
     (define name type)]))

(define-syntax (define syn)
  (syntax-case syn ()
    [(define (name (x : t) ...) body)
     #'(real-define name (lambda* (x : t) ... body))]
    [(define id body)
     #'(real-define id body)]))

(define-syntax-rule (elim t1 t2 e ...)
  ((real-elim t1 t2) e ...))

(begin-for-syntax
  (define (rewrite-clause clause)
    (syntax-case clause (: IH:)
      [((con (a : A) ...) IH: ((x : t) ...) body)
       #'(lambda* (a : A) ... (x : t) ... body)]
      [(e body) #'body])))

;; TODO: Expects clauses in same order as constructors as specified when
;; TODO: inductive D is defined.
;; TODO: Assumes D has no parameters
(define-syntax (case syn)
  ;; duplicated code
  (define (clause-body syn)
    (syntax-case (car (syntax->list syn)) (: IH:)
      [((con (a : A) ...) IH: ((x : t) ...) body) #'body]
      [(e body) #'body]))
  (syntax-case syn (=>)
    [(_ e clause* ...)
     (let* ([D (type-infer/syn #'e)]
            [M (type-infer/syn (clause-body #'(clause* ...)))]
            [U (type-infer/syn M)])
       #`(elim #,D #,U (lambda (x : #,D) #,M) #,@(map rewrite-clause (syntax->list #'(clause* ...)))
               e))]))

(define-syntax (case* syn)
  (syntax-case syn ()
    [(_ D U e (p ...) P clause* ...)
     #`(elim D U P #,@(map rewrite-clause (syntax->list #'(clause* ...))) p ... e)]))

(begin-for-syntax
  (define-struct clause (args types decl body))
  (define ih-dict (make-hash))
  (define (clause-parse syn)
    (syntax-case syn (:)
      [((con (a : A) ...) body)
       (make-clause (syntax->list #'(a ...)) (syntax->list #'(A ...)) #'((a : A) ...) #'body)]
      [(e body)
       (make-clause '() '() #'() #'body)]))

  (define (infer-result clauses)
    (or
     (for/or ([clause clauses])
       (type-infer/syn
        (clause-body clause)
        #:local-env (for/fold ([d '()])
                              ([arg (clause-args clause)]
                               [type (clause-types clause)])
                          (dict-set d arg type))))
     (raise-syntax-error
      'match
      "Could not infer type of result."
      (clause-body (car clauses)))))

  (define (infer-ihs D motive args types)
    (for/fold ([ih-dict (make-immutable-hash)])
              ([type-syn types]
               [arg-syn args]
               ;; NB: Non-hygenic
               #:when (cur-equal? type-syn D))
      (dict-set ih-dict (syntax->datum arg-syn) `(,(format-id arg-syn "ih-~a" arg-syn) . ,#`(#,motive #,arg-syn)))))

  (define (clause->method D motive clause)
    (dict-clear! ih-dict)
    (let* ([ihs (infer-ihs D motive (clause-args clause) (clause-types clause))]
           [ih-args (dict-map
                     ihs
                     (lambda (k v)
                       (dict-set! ih-dict k (car v))
                       #`(#,(car v) : #,(cdr v))))])
      #`(lambda* #,@(clause-decl clause) #,@ih-args #,(clause-body clause)))))

(define-syntax (recur syn)
  (syntax-case syn ()
    [(_ id)
     (dict-ref
      ih-dict
      (syntax->datum #'id)
      (lambda ()
        (raise-syntax-error
         'match
         (format "Cannot recur on ~a" (syntax->datum #'id))
         syn)))]))

;; TODO: Test
(define-syntax (match syn)
  (syntax-case syn ()
    [(_ e clause* ...)
     (let* ([clauses (map clause-parse (syntax->list #'(clause* ...)))]
            [R (infer-result clauses)]
            [D (or (type-infer/syn #'e)
                   (raise-syntax-error 'match "Could not infer discrimnant's type." syn))]
	    [motive #`(lambda (x : #,D) #,R)]
            [U (type-infer/syn R)])
       #`((elim #,D #,U)
            #,motive
	    #,@(map (curry clause->method D motive) clauses)
	    e))]))

(begin-for-syntax
  (define-syntax-class let-clause
    (pattern
      (~or (x:id e) ((x:id (~datum :) t) e))
      #:attr id #'x
      #:attr expr #'e
      #:attr type (cond
                    [(attribute t)
                     ;; TODO: Code duplication in ::
                     (unless (type-check/syn? #'e #'t)
                       (raise-syntax-error
                         'let
                         (format "Term ~a does not have expected type ~a. Inferred type was ~a"
                                 (cur->datum #'e) (cur->datum #'t) (cur->datum (type-infer/syn #'e)))
                         #'e (quasisyntax/loc #'x (x e))))
                     #'t]
                    [(type-infer/syn #'e)]
                    [else
                      (raise-syntax-error
                        'let
                        "Could not infer type of let bound expression"
                        #'e (quasisyntax/loc #'x (x e)))]))))
(define-syntax (let syn)
  (syntax-parse syn
    [(let (c:let-clause ...) body)
     #'((lambda* (c.id : c.type) ... body) c.e ...)]))

;; Normally type checking will only happen if a term is actually used. This forces a term to be
;; checked against a particular type.
(define-syntax (:: syn)
  (syntax-case syn ()
    [(_ pf t)
     (begin
       ;; TODO: Code duplication in let-clause pattern
       (unless (type-check/syn? #'pf #'t)
         (raise-syntax-error
           '::
           (format "Term ~a does not have expected type ~a. Inferred type was ~a"
                   (cur->datum #'pf) (cur->datum #'t) (cur->datum (type-infer/syn #'pf)))
           syn))
       #'(void))]))

(define-syntax (run syn)
  (syntax-case syn ()
    [(_ expr) (normalize/syn #'expr)]))

(define-syntax (step syn)
  (syntax-case syn ()
    [(_ expr)
     (let ([t (step/syn #'expr)])
       (displayln (cur->datum t))
       t)]))

(define-syntax (step-n syn)
  (syntax-case syn ()
    [(_ n expr)
     (for/fold
       ([expr #'expr])
       ([i (in-range (syntax->datum #'n))])
       #`(step #,expr))]))

(define-syntax (query-type syn)
  (syntax-case syn ()
    [(_ term)
     (begin
       (printf "\"~a\" has type \"~a\"~n" (syntax->datum #'term) (syntax->datum (type-infer/syn #'term)))
       ;; Void is undocumented and a hack, but sort of works
       #'(void))]))