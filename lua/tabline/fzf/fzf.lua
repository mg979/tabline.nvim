if vim.fn.exists('g:loaded_fzf') == 0 then
  return {}
end

local a = require'tabline.fzf.ansi'
local c = require'tabline.setup'.settings

-- vim functions {{{1
local fn = vim.fn
local execute = fn.execute
local bufnr = fn.bufnr
local bufname = fn.bufname

-- table functions {{{1
local tbl = require'tabline.table'
local remove = table.remove
local insert = table.insert
local map = tbl.map
local index = tbl.index
local copy = tbl.copy
--}}}

-- fzf statusline highlight {{{1
if fn.expand('$TERM') ~= "256color" then
  vim.cmd([[
  highlight! tnv_fzf1 ctermfg=1 ctermbg=8 guifg=#E12672 guibg=#565656
  highlight! tnv_fzf2 ctermfg=252 ctermbg=238 guifg=#D9D9D9 guibg=#565656
  ]])
else
  vim.cmd([[
  highlight! tnv_fzf1 ctermfg=161 ctermbg=238 guifg=#E12672 guibg=#565656
  highlight! tnv_fzf2 ctermfg=252 ctermbg=238 guifg=#D9D9D9 guibg=#565656
  ]])
end -- }}}

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------

local function mac_no_gnu() -- {{{1
  if fn.has('mac') == 1 and fn.executable('gstat') == 0 then
    vim.cmd([[
    echohl WarningMsg
    echon 'You must install GNU gstat and gdate:'
    echo "\n\tbrew install coreutils"
    echohl None
    ]])
    return true
  end
  return false
end

local function no_sessions()
  local sessions_path = require'tabline.setup'.settings.sessions_dir or fn.stdpath('data') .. '/session'
  local sessions = fn.globpath(sessions_path, '*', false, true)

  if #sessions == 0 then
    print('No saved sessions.')
    return true
  end
  return false
end

local function statusline(prompt) -- {{{1
  vim.cmd('au FileType fzf ++once setlocal statusline=%#xt_fzf1#\\ >\\ %#xt_fzf2#' .. fn.escape(prompt, ' '))
end

--}}}

-------------------------------------------------------------------------------
-- Tab buffers
-------------------------------------------------------------------------------

local function strip(str) return string.gsub(str, '^%s*(.*)%s*', '%1') end

local function format_buffer(_,b) -- {{{1
  local name = bufname(b) == '' and '[Unnamed]' or fn.fnamemodify(bufname(b), ":~:.")
  local flag = b == bufnr() and a.blue('%', 'Conditional') or (b == bufnr('#') and a.magenta('#', 'Special') or ' ')
  local modified = fn.getbufvar(b, '&modified') == 1 and a.red(' [+]', 'Exception') or ''
  local readonly = fn.getbufvar(b, '&modifiable') == 1 and '' or a.green(' [RO]', 'Constant')
  return strip(string.format("[%s] %s\t%s\t%s", a.yellow(b, 'Number'), flag, name, modified .. readonly))
end

local function tab_buffers() -- {{{1
  local bufs = copy(require'tabline.bufs'.valid_bufs())
  local cur, alt = bufnr(), bufnr('#')

  -- put alternate buffer last, then current after it
  if alt ~= -1 and index(bufs, alt) then
    insert(bufs, 1, remove(bufs, index(bufs, alt)))
  end
  insert(bufs, 1, remove(bufs, index(bufs, cur)))

  return map(bufs, format_buffer)
end

-- }}}


--------------------------------------------------------------------------------
-- Closed tabs
--------------------------------------------------------------------------------

local function closed_tabs_list() -- {{{1
  local lines = {}

  for i, tab in ipairs(require'tabline.tabs'.closed) do
    insert(
      lines,
      string.format(
        "%-22s%-38s%s",
        a.yellow(tostring(i)),
        a.cyan(tab.name or fn.fnamemodify(bufname(tab.buf), ":t")),
        tab.wd
      )
    )
  end
  insert(lines, "Tab\tName\t\t\tWorking Directory")
  return tbl.reverse(lines)
end

local function tabreopen(line) -- {{{1
  local tab = string.match(line, '^%s*(%d+)')
  require'tabline.tabs'.reopen(tab)
end

-- }}}


-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------

local function list_buffers()
  statusline("Open Buffer")
  fn['fzf#run'](vim.tbl_deep_extend('force', {
    source = tab_buffers(),
    sink = function(line)
      local _,_,b = string.find(line, '^%s*%[(%d+)%]')
      execute('b ' .. b)
    end,
    options = '--ansi --header-lines=1 --no-preview'
  }, c.fzf_layout))
end

local function closed_tabs()
  statusline("Reopen Tab")
  fn['fzf#run'](vim.tbl_deep_extend('force', {
    source = closed_tabs_list(),
    sink = tabreopen,
    options = '--ansi --header-lines=1 --no-preview'
  }, c.fzf_layout))
end

local function load_session()
  if mac_no_gnu() or no_sessions() then return end
  statusline("Load Session")
  local curloaded, sessions = require'tabline.fzf.sessions'.sessions_list()
  local options = '--ansi --no-preview --header-lines=' .. (curloaded and '2' or '1')
  fn['fzf#run'](vim.tbl_deep_extend('force', {
    source = sessions,
    sink = require'tabline.fzf.sessions'.session_load,
    options = options,
  }, c.fzf_layout))
end

local function delete_session()
  if mac_no_gnu() or no_sessions() then return end
  statusline("Delete Session")
  local _, sessions = require'tabline.fzf.sessions'.sessions_list()
  fn['fzf#run'](vim.tbl_deep_extend('force', {
    source = sessions,
    sink = require'tabline.fzf.sessions'.session_delete,
    options = '--ansi --header-lines=1 --no-preview'
  }, c.fzf_layout))
end

return {
  list_buffers = list_buffers,
  closed_tabs = closed_tabs,
  load_session = load_session,
  delete_session = delete_session,
  save_session = require'tabline.fzf.sessions'.session_save,
  new_session = require'tabline.fzf.sessions'.session_new,
}
