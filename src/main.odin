package ocurses

import "core:fmt"
import "core:os"

import sa "core:container/small_array"

cleanup :: proc(term: ^Terminal) {
  if term.mode == .Raw {
    cook(term)
  }
  os.close(term.tty)
  os.exit(0)
}

main :: proc() {
  example_input_loop()
}
