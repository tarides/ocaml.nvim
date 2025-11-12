local ui = {}

function ui.selecting_floating_window(results, callback)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = vim.o.columns
  local height = #results
  local row = vim.o.lines - height - 2
  local col = (vim.o.columns - width) / 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    title = "",
    border = "single",
  })
  vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, results)

  local current_selection = 1

  local function update_selection()
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "CursorLine", current_selection - 1, 0, -1)
  end

  update_selection()

  vim.keymap.set("n", "<Up>", function()
    if current_selection > 1 then
      current_selection = current_selection - 1
      update_selection()
    end
  end, { buffer = buf })

  vim.keymap.set("n", "<Down>", function()
    if current_selection < #results then
      current_selection = current_selection + 1
      update_selection()
    end
  end, { buffer = buf })

  vim.keymap.set("n", "<CR>", function()
    callback(current_selection)
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

function ui.display_floating_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = vim.o.columns
  local height = math.min(#lines, 8)
  local row = vim.o.lines - height - 2
  local col = (vim.o.columns - width) / 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "single",
    focusable = true,
  })
  vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

function ui.highlight_range(bufnr, namespace, range, hl_group)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  local start_pos = { range.start.line, range.start.character }
  local end_pos = { range["end"].line, range["end"].character }
  vim.hl.range(bufnr, namespace, hl_group, start_pos, end_pos, { regtype = "v", inclusive = false })
end
return ui
