#lang scribble/manual

@(require
  "../defs.rkt"
  scribble/eval)

@(define curnel-eval (curnel-sandbox "(require cur/stdlib/bool cur/stdlib/nat cur/stdlib/sugar)"))

@title{Nat}
@defmodule[cur/stdlib/nat]
This library defines the datatype @racket[Nat] and several functions on them.

@deftogether[(@defthing[Nat Type]
              @defthing[z Nat]
	      @defthing[s (-> Nat Nat)])]{
The natural number datatype.
}

@defproc[(add1 [n Nat]) Nat]{
A more lispy name for @racket[s].

@examples[#:eval curnel-eval
          (s z)
	  (add1 z)]
}

@defproc[(sub1 [n Nat]) Nat]{
Return the predecessor of @racket[n], or @racket[z] is @racket[n] is @racket[z].

@examples[#:eval curnel-eval
          (sub1 (s z))]

}

@defproc[(plus [n Nat] [m Nat]) Nat]{
Add @racket[n] and @racket[m].

@examples[#:eval curnel-eval
          (plus (s z) (s z))
	  (plus z (s z))
	  (plus (s (s z)) (s z))]
}

@defproc[(mult [n Nat] [m Nat]) Nat]{
Multiply @racket[n] and @racket[m].

@examples[#:eval curnel-eval
          (mult (s z) (s z))
	  (mult z (s z))
	  (mult (s (s z)) (s z))]
}


@defproc[(exp [m Nat] [e Nat]) Nat]{
Compute @racket[e] to the @racket[m]th exponent.
Due to limitations in Cur, running @racket[exp] takes to long to be
useful on numbers larger than @racket[(s z)].

@;@examples[#:eval curnel-eval
@;          (exp (s z) (s z))
@;	  (exp z (s z))]
}

@defproc[(square [m Nat]) Nat]{
Compute @racket[m] squared, i.e., @racket[(exp m (s (s z)))].
Due to limitations in Cur, running @racket[square] takes to long to be
useful on numbers larger than @racket[(s z)].

@;@examples[#:eval curnel-eval
@;	  (square z)]
}

@defproc[(nat-equal? [n Nat] [m Nat]) Bool]{
Return @racket[true] if and only if @racket[n] is equal to @racket[m].

@examples[#:eval curnel-eval
          (nat-equal? (s z) (s z))
	  (nat-equal? z (s z))]
}

@defproc[(even? [n Nat]) Bool]{
Return @racket[true] if and only if @racket[n] is even.

@examples[#:eval curnel-eval
          (even? (s z))
	  (even? z)
	  (even? (s (s z)))]

}

@defproc[(odd? [n Nat]) Bool]{
Return @racket[true] if and only if @racket[n] is not even.

@examples[#:eval curnel-eval
          (odd? (s z))
	  (odd? z)
	  (odd? (s (s z)))]
}
