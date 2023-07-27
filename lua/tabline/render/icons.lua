local M = { icons = {} }

-------------------------------------------------------------------------------
-- Icons
-------------------------------------------------------------------------------

local printf = string.format

local g = require'tabline.setup'.global
local s = require'tabline.setup'.settings
local h = require'tabline.highlight'

-- Load devicons and add custom icons {{{1
local ok, icons = pcall(require, 'nvim-web-devicons')
if not ok then
  icons = nil
else
  icons = icons.get_icons()
  icons.fzf = { icon = "", color = "#d0bf41", cterm_color = "185", name = 'fzf' }
  icons.python = { icon = "", color = "#3572A5", cterm_color = "67", name = 'python' }
  icons.default = { icon = "", color = "#6d8086", cterm_color = "66", name = "default" }
end
--}}}

local function make_icons_hi(gcol, tcol)
  local ret, tgc = {}, vim.o.termguicolors
  local gui = tgc and 'gui' or 'cterm'
  local groups = { 'Special', 'Select', 'Extra', 'Visible', 'Hidden' }
  for _, v in ipairs(groups) do
    local bg = h.get_bg('T' .. v)
    local c = tgc and gcol:sub(2) or tcol or require'tabline.term256'.hex2term(gcol:sub(2))
    vim.cmd(printf('hi T%s%s %sbg=%s %sfg=%s', v, c, gui, bg, gui, tgc and gcol or c))
    ret[v] = {}
    ret[v].sel = printf('%%#T%s%s#___%%#T%s#', v, c, v)
    ret[v].dim = printf('%%#T%sDim#___%%#T%s#', v, v)
    ret[v].ncl = printf('%%#T%s#___%%#T%s#', v, v)
  end
  return ret
end

function M.devicon(b, selected)  -- {{{1
  if icons then
    local buf = g.buffers[b.nr]
    if not buf.basename then
      return nil
    end
    local icon = icons[buf.basename] or icons[buf.ext] or icons.default
    if icon then
      local gcol, tcol = icon.color, icon.cterm_color or '250'
      if not M.icons[gcol] then
        M.icons[gcol] = make_icons_hi(
          -- increase contrast for some colors
          gcol:gsub('#56', '#a6'), tcol:gsub('^60$', '126'))
      end
      local hi = M.icons[gcol][b.hi]
      local kind = selected and (not s.colored_icons and 'ncl' or 'sel') or 'dim'
      return hi and string.gsub(hi[kind], '___', icon.icon) or ''
    end
  end
  return nil
end

-- }}}

return M
