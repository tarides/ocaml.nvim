local ocaml = {}

local function get_server()
  local clients = vim.lsp.get_clients {name="ocamllsp"}
  for _, client in ipairs(clients) do
    if client.name == "ocamllsp" then
      return client
    end
  end
end

local function with_server(callback)
  local server = get_server()
  if server then
    return callback(server)
  end
  vim.notify("No OCaml LSP server available", vim.log.levels.ERROR)
end

function ocaml.jump_to_hole(dir, range)
  with_server(function(client)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = {line = row - 1, character = col},
      direction = dir,
      range = range
    }
    local result = client.request_sync("ocamllsp/jumpToTypedHole", params, 1000)
    if not (result and result.result) then
      vim.notify("No typed holes found.", vim.log.levels.WARN)
      return
    end
    local hole_range = result.result
    vim.api.nvim_win_set_cursor(0, {hole_range.start.line+1, hole_range.start.character})
  end)
end

return ocaml
