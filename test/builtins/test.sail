default Order dec

$include <exception_basic.sail>
$include <vector_dec.sail>

function main (() : unit) -> unit = {
  let a = 0x0;
  const b = 32;
  assert(signed(sail_zero_extend(a, b)) == 0);
}
