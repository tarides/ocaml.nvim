local helper = {}

function helper.get_server()
  local clients = vim.lsp.get_clients({ name = "ocamllsp" })
  for _, client in ipairs(clients) do
    if client.name == "ocamllsp" then
      return client
    end
  end
end

function helper.with_server(callback)
  local server = get_server()
  if server then
    return callback(server)
  end
  vim.notify("No OCaml LSP server available", vim.log.levels.ERROR)
end

function helper.request(client, method, params)
  return client.request_sync(method, params, 1000)
end

return helper
