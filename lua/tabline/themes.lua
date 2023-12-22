local printf = string.format
local index = require('tabline.table').index

local M = {}

M.themes = {}
M.available = {
  'default',
  'apprentice',
  'seoul',
  'tomorrow',
  'dracula',
  'molokai',
  'codedark',
  'slate',
  'paper',
  'paramount',
  'eightbit',
}

function M.refresh()
  if not index(M.available, 'themer') and pcall(require, 'themer') then
    table.insert(M.available, 'themer')
  end
end

function M.apply(theme, reload)
  local s = require('tabline.setup').settings
  if M.restore_settings then
    for k, v in pairs(M.restore_settings) do
      s[k] = v
    end
    M.restore_settings = nil
  end
  if reload and theme.reload then
    theme = theme.reload()
  end
  M.current = theme
  local skip = { 'name', 'settings', 'reload' }
  for k, v in pairs(theme) do
    if not index(skip, k) then
      vim.cmd(string.format('hi! ' .. v, k))
    end
  end
  if theme.settings then
    M.restore_settings = {}
    for k, v in pairs(theme.settings) do
      M.restore_settings[k] = s[k]
      s[k] = v
    end
  end
  vim.cmd[[doautocmd <nomodeline> User TablineThemePost]]
end

function M.add(theme)
  if not theme.name then
    print("Error adding tabline theme: theme doesn't have a name")
    return
  end
  M.themes[theme.name] = theme
  table.insert(M.available, theme.name)
end

function M.fmt(arg)
  local ctermfg, ctermbg, guifg, guibg, bold = unpack(arg)
  local b = bold and 'bold' or 'NONE'
  return '%s '
    .. printf(
      'cterm=%s gui=%s ctermfg=%s ctermbg=%s guifg=%s guibg=%s',
      b,
      b,
      ctermfg,
      ctermbg,
      guifg,
      guibg
    )
end

M.refresh()
return M
