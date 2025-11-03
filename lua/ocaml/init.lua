local M = {}

local ui = require("ocaml.ui")

local api = vim.api
local ui = require("ocaml.ui")

-- 5.1 Lua JUT Runtime compatibility
table.unpack = table.unpack or unpack

local config = {
  keymaps = {
    jump_next_hole = "<leader>n",
    jump_prev_hole = "<leader>p",
    construct = "<leader>c",
    jump = "<leader>j",
    phrase_prev = "<leader>pp",
    phrase_next = "<leader>pn",
    infer = "<leader>i",
    switch_ml_mli = "<leader>s",
    type_enclosing = "<leader>t",
    type_enclosing_grow = "<Up>",
    type_enclosing_shrink = "<Down>",
    type_enclosing_increase = "<Right>",
    type_enclosing_decrease = "<Left>",
  }
}

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

function M.jump_to_hole(dir, range, bufnr)
  local buf = bufnr or 0
  with_server(function(client)
    local row, col = table.unpack(api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(buf),
      position = { line = row - 1, character = col },
      direction = dir,
      range = range,
    }
    local result = client.request_sync("ocamllsp/jumpToTypedHole", params, 1000)
    if not result then
      vim.notify("No typed holes found.", vim.log.levels.WARN)
      return
    end
    local hole = result.result
    if hole == nil then
      return
    end
    local win = bufnr and vim.fn.bufwinid(buf) or 0
    api.nvim_win_set_cursor(win, { hole.start.line + 1, hole.start.character })
  end)
end

function M.construct()
  with_server(function(client)
    local row, col = table.unpack(api.nvim_win_get_cursor(0))
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
    local buf = api.nvim_get_current_buf()
    local function apply_choice(choice)
      api.nvim_buf_set_text(buf, row - 1, col, row - 1, col + 1, { choice })
      local range = {
        start = { line = row - 1, character = col },
        ["end"] = { line = row - 1, character = col + #choice },
      }
      M.jump_to_hole("next", range, buf)
      vim.cmd.redraw()
    end

    ui.selecting_floating_window(choices, function(id)
      apply_choice(choices[id])
    end)
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
    local win = vim.fn.bufwinid(api.nvim_get_current_buf())

    if #jumps == 0 then
      vim.notify("Nothing to jump to.", vim.log.levels.INFO)
      return
    end

    local function jump_to(t)
      api.nvim_win_set_cursor(win, { t.position.line + 1, t.position.character })
    end

    if target == "" then
      local targets = vim.tbl_map(function(j)
        return j.target
      end, jumps)
      ui.selecting_floating_window(targets, function(id)
        jump_to(jumps[id])
      end)
    else
      for _, j in ipairs(jumps) do
        if j.target == target then
          jump_to(j)
          return
        end
      end
      vim.cmd.redraw()
      vim.notify("Unable to jump to " .. target, vim.log.levels.INFO)
    end
  end)
end

function merlinCallCompatible(client, command, args)
  local params = {
    uri = vim.uri_from_bufnr(0),
    command = command,
    args = args,
    resultAsSexp = false,
  }
  return client.request_sync("ocamllsp/merlinCallCompatible", params, 1000)
end

function M.phrase(dir)
  with_server(function(client)
    local row, col = table.unpack(api.nvim_win_get_cursor(0))
    local args = {
      "-position",
      row .. ":" .. col,
      "-target",
      dir,
    }
    local result = merlinCallCompatible(client, "phrase", args)
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
    local l = parsed.value.pos.line
    local c = parsed.value.pos.col

    if l > api.nvim_buf_line_count(0) then
      vim.notify("No further phrases found.", vim.log.levels.INFO)
      return
    end
    api.nvim_win_set_cursor(0, { l, c })
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
  local row, col = table.unpack(api.nvim_win_get_cursor(0))
  local args = {
    "-position",
    row + 1 .. ":" .. col,
    "-prefix",
    identifier,
    "-look-for",
    method,
  }
  return merlinCallCompatible(client, "locate", args)
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
    if parsed == nil then
      vim.notify("Failed to parse.", vim.log.levels.ERROR)
      return
    end
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
    if parsed == nil then
      vim.notify("Failed to parse.", vim.log.levels.ERROR)
      return
    end
    vim.cmd.split(parsed.value.file)
    api.nvim_win_set_cursor(0, { parsed.value.pos.line, parsed.value.pos.col })
  end)
end

function M.document_identifier(identifier)
  local row, col = table.unpack(api.nvim_win_get_cursor(0))
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
    if string.find(doc, "\n") then
      ui.display_floating_buffer(vim.split(doc, "\n"))
    else
      print(doc)
    end
  end)
end

local function get_name_typ(l)
  local acc = {}
  for i = 1, #l do
    acc[i] = l[i].name .. " " .. l[i].typ
  end
  return acc
end

local function search_definition_declaration(query, f)
  with_server(function(client)
    local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(0) },
      position = { line = row, character = col },
      query = query,
      limit = 10,
      with_doc = true,
      doc_format = "plaintext",
    }
    local result = client.request_sync("ocamllsp/typeSearch", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to find type " .. query .. ".", vim.log.levels.WARN)
      return
    end
    local choices = result.result
    ui.selecting_floating_window(get_name_typ(choices), function(id)
      local n = choices[id].name
      vim.defer_fn(function()
        f(n)
      end, 10)
    end)
  end)
end

function M.search_declaration(query)
  search_definition_declaration(query, M.find_identifier_decl)
end

function M.search_definition(query)
  search_definition_declaration(query, M.find_identifier_def)
end

function M.type_expression(expression)
  with_server(function(client)
    local row, col = table.unpack(api.nvim_win_get_cursor(0))
    local args = {
      "-position",
      row .. ":" .. col,
      "-expression",
      expression,
    }
    local result = merlinCallCompatible(client, "type-expression", args)
    if not (result and result.result) then
      vim.notify("Unable to find the type of " .. expression, vim.log.levels.WARN)
      return
    end
    local data = result.result.result
    local ok, parsed = pcall(vim.fn.json_decode, data)
    if not ok or not parsed.value or not parsed.value then
      vim.notify("Invalid response from server.", vim.log.levels.ERROR)
      return
    end
    print(parsed.value)
  end)
end

local namespace = vim.api.nvim_create_namespace("lsp_range")
local enclosings = nil
local index = 1
local verbosity = 0
local type = nil

function M.grow_enclosing()
  if enclosings == nil then
    return
  end
  if index >= #enclosings then
    index = 1
  else
    index = index + 1
  end
  local at = enclosings[index]
  local res = M.type_enclosing(at, 0, verbosity)
  type = res.type
  M.display_type(enclosings[index])
end

function M.shrink_enclosing()
  if enclosings == nil then
    return
  end
  if index == 1 then
    index = #enclosings
  else
    index = index - 1
  end
  local at = enclosings[index]
  local res = M.type_enclosing(at, 0, verbosity)
  type = res.type
  M.display_type(enclosings[index])
end

function M.increase_verbosity()
  if enclosings == nil then
    return
  end
  local at = enclosings[index]
  local pretype = type
  local res = M.type_enclosing(at, 0, verbosity + 1)
  if pretype == res.type then
    return
  end
  verbosity = verbosity + 1
  type = res.type
  M.display_type(enclosings[index])
end

function M.decrease_verbosity()
  if enclosings == nil or verbosity == 0 then
    return
  end
  local at = enclosings[index]
  verbosity = verbosity - 1
  local res = M.type_enclosing(at, 0, verbosity)
  type = res.type
  M.display_type(enclosings[index])
end

function M.start_session()
  if vim.b.in_special_mode then
    return
  end
  vim.b.in_special_mode = true
  vim.keymap.set("n", config.keymaps.type_enclosing_grow, function()
    M.grow_enclosing()
  end, { buffer = true, desc = "Grow enclosing" })
  vim.keymap.set("n", config.keymaps.type_enclosing_shrink, function()
    M.shrink_enclosing()
  end, { buffer = true, desc = "Shrink enclosing" })
  vim.keymap.set("n", config.keymaps.type_enclosing_increase, function()
    M.increase_verbosity()
  end, { buffer = true, desc = "Increase verbosity" })
  vim.keymap.set("n", config.keymaps.type_enclosing_decrease, function()
    M.decrease_verbosity()
  end, { buffer = true, desc = "Decrease verbosity" })

  local function stop_session()
    enclosings = nil
    index = 1
    verbosity = 0
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    if not vim.b.in_special_mode then
      return
    end
    vim.b.in_special_mode = false
    vim.keymap.del("n", config.keymaps.type_enclosing_grow, { buffer = true })
    vim.keymap.del("n", config.keymaps.type_enclosing_shrink, { buffer = true })
    vim.keymap.del("n", config.keymaps.type_enclosing_increase, { buffer = true })
    vim.keymap.del("n", config.keymaps.type_enclosing_decrease, { buffer = true })
    vim.api.nvim_clear_autocmds({ group = "EnclosingSession" })
  end

  local group = vim.api.nvim_create_augroup("EnclosingSession", { clear = true })
  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    group = group,
    buffer = 0,
    once = true,
    callback = stop_session,
  })
end

function M.type_enclosing(at, offset, v)
  local res
  with_server(function(client)
    local params = {
      uri = vim.uri_from_bufnr(0),
      at = at,
      index = offset,
      verbosity = v,
    }
    local result = client.request_sync("ocamllsp/typeEnclosing", params, 1000)
    if not (result and result.result) then
      vim.notify("Unable to do the type enclosing.", vim.log.levels.WARN)
      return
    end
    res = result.result
  end)
  return res
end

function M.display_type(range)
  if type == nil then
    vim.notify("No type to display.", vim.log.levels.WARN)
    return
  end
  if string.find(type, "\n") then
    print()
    ui.display_floating_buffer(vim.split(type, "\n"))
  else
    print(type)
  end
  ui.highlight_range(0, namespace, range, "Search")
end

function M.enter_type_enclosing()
  local row, col = table.unpack(api.nvim_win_get_cursor(0))
  local at = { line = row - 1, character = col }
  local result = M.type_enclosing(at, 0, verbosity)
  type = result.type
  enclosings = result.enclosings
  index = 1
  M.display_type(enclosings[index])
  M.start_session()
end

--- Initialize the OCaml plugin
---@param user_config any
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
  local _ = config

  api.nvim_create_autocmd("FileType", {
    pattern = { "ocaml", "ocaml.interface" },
    callback = function()
      vim.api.nvim_create_user_command("OCamlJumpNextHole", function()
        M.jump_to_hole("next")
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.jump_next_hole,
        "<CMD>OCamlJumpNextHole<CR>",
        { desc = "OCaml: Jump to the next hole" }
      )

      vim.api.nvim_create_user_command("OCamlJumpPrevHole", function()
        M.jump_to_hole("prev")
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.jump_prev_hole,
        "<CMD>OCamlJumpPrevHole<CR>",
        { desc = "OCaml: Jump to the previous hole" }
      )

      vim.api.nvim_create_user_command("OCamlConstruct", function()
        M.construct()
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.construct,
        "<CMD>OCamlConstruct<CR>",
        { desc = "OCaml: Open a list of valid substitutions to fill the hole" }
      )

      vim.api.nvim_create_user_command("OCamlJump", function(opts)
        M.jump(opts.args)
      end, { nargs = "?" })
      vim.keymap.set(
        "n",
        config.keymaps.jump,
        "<CMD>OCamlJump<CR>",
        { desc = "OCaml: Open a list of valid jump from this location" }
      )

      vim.api.nvim_create_user_command("OCamlPhrasePrev", function()
        M.phrase("prev")
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.phrase_prev,
        "<CMD>OCamlPhrasePrev<CR>",
        { desc = "OCaml: Jump to the beginning of the previous phrase" }
      )

      vim.api.nvim_create_user_command("OCamlPhraseNext", function()
        M.phrase("next")
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.phrase_next,
        "<CMD>OCamlPhraseNext<CR>",
        { desc = "OCaml: Jump to the beginning of the next phrase" }
      )

      vim.api.nvim_create_user_command("OCamlInferIntf", function()
        M.infer_intf()
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.infer,
        "<CMD>OCaml<CR>",
        { desc = "OCaml: Infer the interface of the associated implementation file" }
      )

      vim.api.nvim_create_user_command("OCamlSwitchIntfImpl", function()
        M.switch_file()
      end, {})
      vim.keymap.set(
        "n",
        config.keymaps.switch_ml_mli,
        "<CMD>OCamlSwitchIntfImpl<CR>",
        { desc = "OCaml: Switch between `.ml` and `.mli` file" }
      )

      vim.api.nvim_create_user_command("OCamlFindIdentifierDefinition", function(opts)
        M.find_identifier_def(opts.args)
      end, { nargs = 1 })

      vim.api.nvim_create_user_command("OCamlFindIdentifierDeclaration", function(opts)
        M.find_identifier_decl(opts.args)
      end, { nargs = 1 })

      vim.api.nvim_create_user_command("OCamlDocumentIdentifier", function(opts)
        M.document_identifier(opts.args)
      end, { nargs = 1 })

      vim.api.nvim_create_user_command("OCamlSearchDeclaration", function(opts)
        M.search_declaration(opts.args)
      end, { nargs = 1 })

      vim.api.nvim_create_user_command("OCamlSearchDefinition", function(opts)
        M.search_definition(opts.args)
      end, { nargs = 1 })

      api.nvim_create_user_command("TypeExpression", function(opts)
        M.type_expression(opts.args)
      end, { nargs = 1 })
    end,
  })
end

return M
