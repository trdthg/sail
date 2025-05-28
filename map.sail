default Order dec
$include <prelude.sail>

val m1 : bits(1) <-> int

val mc2 : int <-> bits(2)
mapping clause mc2 = m1(x) @ 0b0 <-> x // Does not compile

