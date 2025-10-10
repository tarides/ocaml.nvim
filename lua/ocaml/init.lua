local helper = require("helpers")
local ocaml = {}

function ocaml.jump_to_hole(dir, range)
  helper.with_server(function(client)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = { line = row - 1, character = col },
      direction = dir,
      range = range,
    }
    local result = helper.request(client, "ocamllsp/jumpToTypedHole", params)
    if not (result and result.result) then
      vim.notify("No typed holes found.", vim.log.levels.WARN)
      return
    end
    local hole_range = result.result
    vim.api.nvim_win_set_cursor(0, { hole_range.start.line + 1, hole_range.start.character })
  end)
end

function ocaml.construct(input)
  helper.with_server(function(client)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local params = {
      uri = vim.uri_from_bufnr(0),
      position = { line = row - 1, character = col },
      withValues = "local",
    }
    local result = helper.request(client, "ocamllsp/construct", params)
    if not (result and result.result) then
      vim.notify("Unable to construct.", vim.log.levels.WARN)
      return
    end

    local choices = result.result.result

    local function apply_choice(choice)
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, { choice })
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

function ocaml.jump(target)
  helper.with_server(function(client)
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local result = helper.request(client, "ocamllsp/jump", params)
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
        vim.api.nvim_win_set_cursor(0, { j.position.line + 1, j.position.character })
        return
      end
    end
    vim.cmd.redraw()
    vim.notify("Unable to jump to " .. target, vim.log.levels.INFO)
  end)
end

function ocaml.phrase(dir)
  helper.with_server(function(client)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
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
    local result = helper.request(client, "ocamllsp/merlinCallCompatible", params)
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

    if line > vim.api.nvim_buf_line_count(0) then
      vim.notify("No further phrases found.", vim.log.levels.INFO)
      return
    end
    vim.api.nvim_win_set_cursor(0, { line, col })
  end)
end

--- Initialize the OCaml plugin
---@param config any
function ocaml.setup(config)
  -- No config yet, itt can be ignored.
  local _ = config

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "ocaml", "ocaml.interface" },
    callback = function()
      vim.api.nvim_create_user_command("JumpNextHole", function()
        ocaml.jump_to_hole("next")
      end, {})

      vim.api.nvim_create_user_command("JumpPrevHole", function()
        ocaml.jump_to_hole("prev")
      end, {})

      vim.api.nvim_create_user_command("Construct", function()
        ocaml.construct()
      end, {})

      vim.api.nvim_create_user_command("Jump", function(opts)
        ocaml.jump(opts.args)
      end, { nargs = 1 })

      vim.api.nvim_create_user_command("PhrasePrev", function()
        ocaml.phrase("prev")
      end, {})

      vim.api.nvim_create_user_command("PhraseNext", function()
        ocaml.phrase("next")
      end, {})
    end,
  })
end

return ocaml
