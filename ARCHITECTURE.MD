Architecture of `ocaml.nvim`
-----

### lua/ocaml/

`config.lua` defines the default keybindings for the user, which can be
overwritten in the configuration of the installed plugin.

`init.lua` is the main file of the plugin because it defines all the functions.
It is separated into three parts:
  - The connection to the OCaml LSP server functions, `get_server` and
  `with_server`, that are used by every function.
  - The functions of the plugin that are part of the table `M`, and the helper
  functions that are locals and private.
  - The function `setup` creates all the new commands and links them to a
  command name and to the functions defined before.

`ui.lua` defines complex ui entities that are used by the functions of
`init.lua`.
  - `selecting_floating_window` opens a floating window where each line
  corresponds to a choice. It is used by `jump` to let the user select where he
  wants to jump. `construct` also displays the different possibilities of types
  you can construct on the `_` where the cursor is. When it appears, the window
  will be at the bottom of the screen, and focus will automatically be given to
  the new window. The arrows are used to select the choice, and `escape` to
  close the window if no choices can be made.
  - `display_floating_buffer` opens a floating window at the bottom of the
  screen, so as not to be disturbing. It is used in `document_identifier` when
  the documentation spans multiple lines. `type_enclosing` used it as well in
  the same circumstances, when the type displayed exceeds one line. The window
  size is between the number of lines to display and 8 lines of height. This is
  an arbitrary choice, not to make it too big, one more time with a disturbing
  concern. The window is also set to non-modifiable because the displayed
  information is read-only. Once opened, the focus will switch to this
  read-only floating window, which can be closed by hitting `escape`.
  - `highlight_range` highlights the range given as a parameter. It is used with
  `type_enclosing`.

### media/

This directory contains all media files displayed in [README.md](README.md).

### tests/

`fixtures/` stores the ocaml files on which the tests are ran.

`init.lua` set up and run the tests.

`jump_logic.lua` implements logical `jump_prev`, `jump_next` and `construct`
functions to compare their functionning to the real one.

`jump_spec.lua` defines the loop to run the property based testing like tests of
jump. It takes `n` times random function from the pull of functions,
`jump_prev`, `jump_next` and `construct`, and compare the logical functionning
to the one of the plugin and assert that it behave the same.
