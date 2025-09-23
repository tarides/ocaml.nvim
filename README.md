# ocaml.nvim

`ocaml.nvim` provides direct access to advanced `ocamllsp` features without
requiring complex editor-side logic.
`ocaml.nvim` aims to offer a fast, simple, and modular workflow in Neovim.
This plugin gives access to all the advanced Merlin commands not supported by
generic LSP clients, such as Construct, alternate between `.mli` and `.ml`
files, etc.

## Installation using `lazy.nvim`
Add the plugin to your `lazy.nvim` setup:

```lua
require("lazy").setup({
  { "tarides/ocaml.nvim",
    lazy = false,
    config = function()
      require("ocaml")
    end
  }
})
```

## Features
Here is the list of commands offered by `ocaml.nvim` and their key binding.
All of the commands are detailed and illustrated in the following sections.

> [!IMPORTANT]
> This section only covers features specific to `ocaml.nvim`.
> However, the builtin LSP of Neovim already provides standards commands such as
> go-to-definition and hover documentation.

| Command | Default Binding | Description |
| -- | -- | -- |
| `JumpPrevHole` | -- | Jump to the previous hole. |
| `JumpNextHole` | -- | Jump to the next hole. |
| `Construct` | -- | Open up a list of valid substitutions to fill the hole. |

### Construct expression

Enables you to navigate between typed-holes (`_`) in a document and
interactively substitute them:

- `JumpPrevHole`: jump to the next hole
- `JumpNextHole`: jump to the previous hole
- `Construct`: open up a list of valid substitutions to fill the hole

![Construct example](media/construct.gif)
