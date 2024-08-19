default Order dec
$include <prelude.sail>

union ast = {
  B : (bool),
  Z : unit
}

mapping bool_not_bits : bool <-> bits(1) = {
  true   <-> 0b0,
  false  <-> 0b1,
}

let false_val = false
let false_2 = false == true

mapping encdec  : bits(2) <->  ast = {
  0b1 @ bool_not_bits(s) <-> B(s),
  0b01 if true <-> Z(),
  0b00 if false_val <-> Z(),
  0b00 if false_val == true <-> Z(),
  0b00 <-> Z(),
}

val main : unit -> unit
function main() = {
    let encdec_value = encdec(0b00)
}