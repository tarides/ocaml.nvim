Contributing to `ocaml.nvim`
-----

Thank you for your interest in this project!
All contributions are welcome whether it’s fixing a bug, improving documentation, adding a new feature or some tests.

## Code of Conduct

`ocaml.nvim` adheres to the OCaml Code of Conduct as stated in the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior either to local contacts (listed in [here](CODE_OF_CONDUCT.md)) or to someone listed in the upstream [OCaml Code of Conduct](CODE_OF_CONDUCT.md).

## Documentation

This repository contains some files with different objectives.

[README.md](README.md) is the entry point for users, containing all installation and customization instructions, a description of all available features, and a video recording for all of them.

[ARCHITECTURE.md](ARCHITECTURE.md) explains how the repository is structured and what the purpose of each file is in the different directories.

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) references the code of conduct for the OCaml ecosystem, which this project also follows.

[CHANGES.md](CHANGES.md) indexes all the changes made to the project, and organizes them among the release versions.

[CONTRIBUTING.md](CONTRIBUTING.md) is the current file that aims to describe everything a developer needs to know, beyond the codebase, to contribute efficiently to the project.

## How to contribute

1. Open an Issue
   - Before starting any work, please open an issue to describe what you want to add or change.
   - This avoids duplicate efforts and helps coordinate work.

2. Fork and Branch
   - Fork the repository
   - Create a descriptive branch
   - Open a Pull Request with your changes and a changelog entry. The maintainers will review it.

### How to add a new feature in the codebase

1. Add a new function in the table `M` to define what the new feature is going to do. For communication with the OCaml Language Server Protocol, use the `with_server` function to get a client instance with which you can communicate via LSP requests. Feel free to add intermediate functions or use/add UI functions.

2. In the `setup` function, add a new entry to register the new command.

3. Add the keymap by default in the `config` file.
