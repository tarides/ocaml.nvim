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
