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

return ui
