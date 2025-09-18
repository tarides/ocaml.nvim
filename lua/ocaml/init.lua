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

function ocaml.construct(input)
  with_server(function(client)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = {line = row - 1, character = col},
      withValues = "local"
    }
    local result = client.request_sync("ocamllsp/construct", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to construct.", vim.log.levels.WARN)
      return
    end

    local choices = result.result.result

    local function apply_choice(choice)
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, {choice})
      local range = {
        start = { line = row - 1, character = col },
        ["end"] = { line = row - 1, character = col + #choice }
      }
      require("ocaml").jump_to_hole("next", range)
      vim.cmd.redraw()
    end

    if input then
      local choice = choices[input]
      if choice then
        apply_choice(choice)
      end
    else
      vim.ui.select(choices, {prompt = "Choose a construct:"}, function(choice)
        if choice then
          apply_choice(choice)
        end
      end)
    end
  end)
end

function ocaml.construct_for_test(input)
  with_server(function(client)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = {line = row - 1, character = col},
      withValues = "local"
    }
    local result = client.request_sync("ocamllsp/construct", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to construct.", vim.log.levels.WARN)
      return
    end

    local choices = result.result.result
    local choice = choices[input]
    if not choice then return end
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, {choice})
    if choice:find("_") then
      require("ocaml").jump_to_hole("next")
    end
  end)
end

return ocaml
