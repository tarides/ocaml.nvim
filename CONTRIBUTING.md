Contributing to `ocaml.nvim`
-----

Thank you for your interest in this project!
All contributions are welcome whether it’s fixing a bug, improving documentation, adding a new feature or some tests.

## How to contribute

1. Open an Issue
   - Before starting any work, please open an issue to describe what you want to add or change.
   - This avoids duplicate efforts and helps coordinate work.

2. Fork and Branch
   - Fork the repository
   - Create a descriptive branch
   - Open a Pull Request with your changes and a changelog entry. The maintainers will review it.

Please find the [ARCHITECTURE.md](ARCHITECTURE.md) detailing the plugin's architecture.

### How to add a new feature in the codebase

1. Add a new function in the table `M` to define what the new feature is going to do. For communication with the OCaml Language Server Protocol, use the `with_server` function to get a client instance with which you can communicate via LSP requests. Feel free to add intermediate functions or use/add UI functions.

2. In the `setup` function, add a new entry to register the new command.

3. Add the keymap by default in the `config` file.
