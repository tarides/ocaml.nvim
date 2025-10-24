local ui = {}

function ui.display_floating_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = vim.o.columns
  local height = math.min(#lines, 8)
  local row = vim.o.lines - height - 2
  local col = (vim.o.columns - width) / 2

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "single",
    focusable = true,
  })
  vim.api.nvim_set_option_value("winhl", "Normal:Normal", { buf = win })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local group = vim.api.nvim_create_augroup("FloatingClose", { clear = true })

  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.api.nvim_clear_autocmds({ group = group })
  end

  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    group = group,
    pattern = "*",
    once = true,
    callback = close,
  })
end

function ui.highlight_range(bufnr, namespace, range, hl_group)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  local start_pos = { range.start.line, range.start.character }
  local end_pos = { range["end"].line, range["end"].character }
  vim.hl.range(bufnr, namespace, hl_group, start_pos, end_pos, { regtype = "v", inclusive = false })
end
return ui
