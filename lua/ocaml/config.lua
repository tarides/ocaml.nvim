local vim = vim
local M = {}

---@class OCamlConfigKeymaps
---@field jump_next_hole string|?
---@field jump_prev_hole string|?
---@field construct string|?
---@field jump string|?
---@field phrase_prev string|?
---@field phrase_next string|?
---@field infer string|?
---@field switch_ml_mli string|?
---@field type_enclosing string|?
---@field type_enclosing_grow string|?
---@field type_enclosing_shrink string|?
---@field type_enclosing_increase string|?
---@field type_enclosing_decrease string|?

---@class ocaml.config.OCamlConfig
---@field keymaps OCamlConfigKeymaps

--- Default values
--- @type ocaml.config.OCamlConfig
local default = {
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
  },
}

--- Extends the configuration with user config
---@return ocaml.config.OCamlConfig
function M.build(user_config)
  user_config = user_config or {}

  local config = default
  for k, v in pairs(user_config) do
    if config[k] ~= nil then
      config[k] = v
    end
  end
  return config
end

return M
