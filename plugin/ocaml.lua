vim.api.nvim_create_autocmd("FileType", {
  pattern = { "ocaml", "ocaml.interface" },
  callback = function()
    vim.api.nvim_buf_create_user_command(0, "JumpNextHole", function()
      require("ocaml").jump_to_hole("next")
    end, {})

    vim.api.nvim_buf_create_user_command(0, "JumpPrevHole", function()
      require("ocaml").jump_to_hole("prev")
    end, {})

    vim.api.nvim_create_user_command("Construct", function()
      require("ocaml").construct()
    end, {})

    vim.api.nvim_create_user_command("Jump", function(opts)
      require("ocaml").jump(opts.args)
    end, { nargs = 1 })

    vim.api.nvim_create_user_command("PhrasePrev", function()
      require("ocaml").phrase("prev")
    end, {})

    vim.api.nvim_create_user_command("PhraseNext", function()
      require("ocaml").phrase("next")
    end, {})
  end,
})

