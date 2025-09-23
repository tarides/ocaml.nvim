vim.cmd("set rtp+=.")
vim.cmd("set rtp+=~/.local/share/nvim/lazy/plenary.nvim")
package.path = "./tests/?.lua;" .. package.path

local ocamllsp_path = vim.fn.exepath("ocamllsp")
if ocamllsp_path == "" then
  print("ocamllsp not found, skipping test")
  return
end

vim.cmd("edit tests/fixtures/jump.ml")
local bufnr = vim.api.nvim_get_current_buf()

vim.lsp.start {
  name = "ocamllsp",
  cmd = { ocamllsp_path },
  root_dir = vim.fn.getcwd(),
  filetypes = { "ocaml", "ocaml.interface" },
}

local params = vim.lsp.util.make_text_document_params(bufnr)
for _, client in pairs(vim.lsp.get_clients({ name = "ocamllsp" })) do
  client.notify("textDocument/didOpen", params)
end

vim.wait(2000, function()
  for _, client in ipairs(vim.lsp.get_clients({ name = "ocamllsp" })) do
    if client.attached_buffers then
      for _, b in ipairs(client.attached_buffers) do
        if b == bufnr then return true end
      end
    end
  end
  return false
end, 50, false)

require("plenary.busted")

require("jump_spec").runtest(bufnr, 42, 500)

vim.cmd("qa!")
