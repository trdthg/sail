let file = open_out "/tmp/yacht_sail.log"

let log str =
  output_string file (str ^ "\n");
  flush file

let debug fmt = Format.kasprintf log fmt
