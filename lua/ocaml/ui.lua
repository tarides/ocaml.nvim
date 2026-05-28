local ui = {}

-- `selecting_floating_window` opens a floating window where each line
--    corresponds to a choice. It is used by `jump` to let the user select where he
--    wants to jump. `construct` also displays the different possibilities of types
--    you can construct on the `_` where the cursor is. When it appears, the window
--    will be at the bottom of the screen, and focus will automatically be given to
--    the new window. The arrows are used to select the choice, and `escape` to
--    close the window if no choices can be made.
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

-- `display_floating_buffer` opens a floating window at the bottom of the
--    screen, so as not to be disturbing. It is used in `document_identifier` when
--    the documentation spans multiple lines. `type_enclosing` used it as well in
--    the same circumstances, when the type displayed exceeds one line. The window
--    size is between the number of lines to display and 8 lines of height. This is
--    an arbitrary choice, not to make it too big, one more time with a disturbing
--    concern. The window is also set to non-modifiable because the displayed
--    information is read-only. Once opened, the focus will switch to this
--    read-only floating window, which can be closed by hitting `escape`.
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

-- `highlight_range` highlights the range given as a parameter. It is used with
--    `type_enclosing`.
function ui.highlight_range(bufnr, namespace, range, hl_group)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  local start_pos = { range.start.line, range.start.character }
  local end_pos = { range["end"].line, range["end"].character }
  vim.hl.range(bufnr, namespace, hl_group, start_pos, end_pos, { regtype = "v", inclusive = false })
end
return ui
