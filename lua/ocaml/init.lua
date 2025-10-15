local M = {}

local api = vim.api

local function get_server()
  local clients = vim.lsp.get_clients({ name = "ocamllsp" })
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

function M.jump_to_hole(dir, range)
  with_server(function(client)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = { line = row - 1, character = col },
      direction = dir,
      range = range,
    }
    local result = client.request_sync("ocamllsp/jumpToTypedHole", params, 1000)
    if not (result and result.result) then
      vim.notify("No typed holes found.", vim.log.levels.WARN)
      return
    end
    local hole_range = result.result
    api.nvim_win_set_cursor(0, { hole_range.start.line + 1, hole_range.start.character })
  end)
end

function M.construct(input)
  with_server(function(client)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = { line = row - 1, character = col },
      withValues = "local",
    }
    local result = client.request_sync("ocamllsp/construct", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to construct.", vim.log.levels.WARN)
      return
    end

    local choices = result.result.result

    local function apply_choice(choice)
      api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, { choice })
      local range = {
        start = { line = row - 1, character = col },
        ["end"] = { line = row - 1, character = col + #choice },
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
      vim.ui.select(choices, { prompt = "Choose a construct:" }, function(choice)
        if choice then
          apply_choice(choice)
        end
      end)
    end
  end)
end

function M.jump(target)
  with_server(function(client)
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local result = client.request_sync("ocamllsp/jump", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to jump.", vim.log.levels.WARN)
      return
    end
    local jumps = result.result.jumps
    if #jumps == 0 then
      vim.notify("Nothing to jump to.", vim.log.levels.INFO)
      return
    end
    for _, j in ipairs(jumps) do
      if j.target == target then
        api.nvim_win_set_cursor(0, { j.position.line + 1, j.position.character })
        return
      end
    end
    vim.cmd.redraw()
    vim.notify("Unable to jump to " .. target, vim.log.levels.INFO)
  end)
end

function M.phrase(dir)
  with_server(function(client)
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      command = "phrase",
      args = {
        "-position",
        row .. ":" .. col,
        "-target",
        dir,
      },
      resultAsSexp = false,
    }
    local result = client.request_sync("ocamllsp/merlinCallCompatible", params, 1000)
    if not (result and result.result) then
      vim.notify("No OCaml phrase found at cursor.", vim.log.levels.WARN)
      return
    end
    local data = result.result.result
    local ok, parsed = pcall(vim.fn.json_decode, data)
    if not ok or not parsed.value or not parsed.value.pos then
      vim.notify("Invalid response from server.", vim.log.levels.ERROR)
      return
    end
    local line = parsed.value.pos.line
    local col = parsed.value.pos.col

    if line > api.nvim_buf_line_count(0) then
      vim.notify("No further phrases found.", vim.log.levels.INFO)
      return
    end
    api.nvim_win_set_cursor(0, { line, col })
  end)
end

local function is_buf_empty(buf)
  local line_count = api.nvim_buf_line_count(buf)
  local first_line = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  return first_line == "" and line_count == 1
end

local function unsafe_toggle_ml_mli(buf)
  local fname = api.nvim_buf_get_name(buf)
  local target = fname:match("%.mli$") and fname:gsub("%.mli$", ".ml") or fname:gsub("%.ml$", ".mli")
  vim.cmd.edit(target)
end

local function load_pair(buf)
  unsafe_toggle_ml_mli(buf)
  unsafe_toggle_ml_mli(buf)
end

function M.infer_intf()
  local fname = api.nvim_buf_get_name(0)
  if not (fname:match("%.mli$")) then
    vim.notify("Not an interface file.", vim.log.levels.WARN)
    return
  end
  with_server(function(client)
    local mlfile = fname:gsub("%.mli", ".ml")
    if vim.fn.filereadable(mlfile) == 0 then
      vim.notify("Source file not found: " .. mlfile, vim.log.levels.WARN)
      return
    end
    load_pair(0)
    local result = client.request_sync("ocamllsp/inferIntf", { vim.uri_from_fname(mlfile) }, 1000)
    if not (result and result.result) then
      vim.notify("Unable to infer the interface.", vim.log.levels.WARN)
      return
    end
    local intf_lines = vim.split(result.result, "\n", { plain = true })
    if is_buf_empty(0) then
      api.nvim_buf_set_lines(0, 0, -1, false, intf_lines)
      return
    end
    api.nvim_buf_set_lines(0, 0, -1, false, intf_lines)
  end)
end

function M.switch_file()
  with_server(function(client)
    local result = client.request_sync("ocamllsp/switchImplIntf", { vim.uri_from_bufnr(0) }, 1000)
    if not (result and result.result) then
      vim.notify("No file to switch founded.", vim.log.levels.WARN)
      return
    end
    local target = vim.uri_to_fname(result.result[1])
    if vim.fn.filereadable(target) == 1 then
      vim.cmd.edit(target)
      return
    end
    vim.cmd.edit(target)
  end)
end

local function find_identifier(client, identifier, method)
  local row, col = unpack(api.nvim_win_get_cursor(0))
  local params = {
    uri = vim.uri_from_bufnr(0),
    command = "locate",
    args = {
      "-position",
      row + 1 .. ":" .. col,
      "-prefix",
      identifier,
      "-look-for",
      method,
    },
    resultAsSexp = false,
  }
  return client.request_sync("ocamllsp/merlinCallCompatible", params, 1000)
end

local function parse(data)
  local ok, parsed = pcall(vim.fn.json_decode, data)
  if not ok or not parsed.value or not parsed.value.pos then
    vim.notify("Invalid response from server.", vim.log.levels.ERROR)
    return
  end
  return parsed
end

function M.find_identifier_def(identifier)
  with_server(function(client)
    local result = find_identifier(client, identifier, "implementation")
    if not (result and result.result) then
      vim.notify("No definition for identifier " .. identifier .. ".", vim.log.levels.WARN)
      return
    end
    local data = result.result.result
    local parsed = parse(data)
    vim.cmd.split(parsed.value.file)
    api.nvim_win_set_cursor(0, { parsed.value.pos.line, parsed.value.pos.col })
  end)
end

function M.find_identifier_decl(identifier)
  with_server(function(client)
    local result = find_identifier(client, identifier, "interface")
    if not (result and result.result) then
      vim.notify("No declaration for identifier " .. identifier .. ".", vim.log.levels.WARN)
      return
    end
    local data = result.result.result
    local parsed = parse(data)
    vim.cmd.split(parsed.value.file)
    api.nvim_win_set_cursor(0, { parsed.value.pos.line, parsed.value.pos.col })
  end)
end

function M.document_identifier(identifier)
  local row, col = unpack(api.nvim_win_get_cursor(0))
  with_server(function(client)
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(0) },
      position = { line = row, character = col },
      identifier = identifier,
    }
    local result = client.request_sync("ocamllsp/getDocumentation", params, 1000)
    if not (result and result.result) then
      vim.notify("No documentation found for " .. identifier, vim.log.levels.WARN)
      return
    end
    local doc = result.result.doc.value
    print(doc)
  end)
end

--- Initialize the OCaml plugin
---@param config any
function M.setup(config)
  -- No config yet, itt can be ignored.
  local _ = config

  api.nvim_create_autocmd("FileType", {
    pattern = { "ocaml", "ocaml.interface" },
    callback = function()
      api.nvim_buf_create_user_command(0, "JumpNextHole", function()
        M.jump_to_hole("next")
      end, {})

      api.nvim_buf_create_user_command(0, "JumpPrevHole", function()
        M.jump_to_hole("prev")
      end, {})

      api.nvim_create_user_command("Construct", function()
        M.construct()
      end, {})

      api.nvim_create_user_command("Jump", function(opts)
        M.jump(opts.args)
      end, { nargs = 1 })

      api.nvim_create_user_command("PhrasePrev", function()
        M.phrase("prev")
      end, {})

      api.nvim_create_user_command("PhraseNext", function()
        M.phrase("next")
      end, {})

      api.nvim_create_user_command("InferIntf", function()
        M.infer_intf()
      end, {})

      api.nvim_create_user_command("AlternateFile", function()
        M.switch_file()
      end, {})

      api.nvim_create_user_command("FindIdentifierDefinition", function(opts)
        M.find_identifier_def(opts.args)
      end, { nargs = 1 })

      api.nvim_create_user_command("FindIdentifierDeclaration", function(opts)
        M.find_identifier_decl(opts.args)
      end, { nargs = 1 })

      api.nvim_create_user_command("DocumentIdentifier", function(opts)
        M.document_identifier(opts.args)
      end, { nargs = 1 })
    end,
  })
end

return M
