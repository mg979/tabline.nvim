if vim.fn.exists('g:loaded_fzf') == 0 then
  return nil
end

local g = require'tabline.setup'.global
local s = require'tabline.setup'.settings
local h = require'tabline.helpers'
local a = require'tabline.fzf.ansi'

-- vim functions {{{1
local fn = vim.fn
local argv = vim.fn.argv
local tabpagenr = vim.fn.tabpagenr
local tabpagebuflist = vim.fn.tabpagebuflist
local getcwd = vim.fn.getcwd
local haslocaldir = vim.fn.haslocaldir
local execute = vim.fn.execute
local bufnr = vim.fn.bufnr
local bufname = vim.fn.bufname

-- table functions {{{1
local tbl = require'tabline.table'
local remove = table.remove
local concat = table.concat
local insert = table.insert
local sort = table.sort
local filter = tbl.filter
local map = tbl.map
local mapnew = tbl.mapnew
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

local function statusline(prompt) -- {{{1
  vim.cmd('au FileType fzf ++once setlocal statusline=%#xt_fzf1#\\ >\\ %#xt_fzf2#' .. fn.escape(prompt, ' '))
end

--}}}

-------------------------------------------------------------------------------
-- Tab buffers
-------------------------------------------------------------------------------

local function strip(str) return string.gsub(str, '^%s*(.*)%s*', '%1') end

local function format_buffer(k,b) -- {{{1
  local name = bufname(b) == '' and '[Unnamed]' or fn.fnamemodify(bufname(b), ":~:.")
  local flag = b == bufnr() and a.blue('%', 'Conditional') or (b == bufnr('#') and a.magenta('#', 'Special') or ' ')
  local modified = fn.getbufvar(b, '&modified') == 1 and a.red(' [+]', 'Exception') or ''
  local readonly = fn.getbufvar(b, '&modifiable') == 1 and '' or a.green(' [RO]', 'Constant')
  return strip(string.format("[%s] %s\t%s\t%s", a.yellow(b, 'Number'), flag, name, modified .. readonly))
end

local function tab_buffers() -- {{{1
  local bufs = copy(require'tabline.bufs'.get_bufs(true))
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
    insert(lines, string.format('%-5s%-20s%s', a.yellow(tostring(i)), a.cyan(tab.name), tab.wd))
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
  fn['fzf#run']({
      source = tab_buffers(),
      sink = function(line)
        local _,_,b = string.find(line, '^%s*%[(%d+)%]')
        execute('b ' .. b)
      end,
      down = '30%',
      options = '--ansi --header-lines=1 --no-preview'
    })
end

local function closed_tabs()
  statusline("Reopen Tab")
  fn['fzf#run']({
      source = closed_tabs_list(),
      sink = tabreopen,
      down = '30%',
      options = '--ansi --header-lines=1 --no-preview'
    })
end

local function load_session()
  if mac_no_gnu() then return end
  statusline("Load Session")
  local curloaded, sessions = require'tabline.fzf.sessions'.sessions_list()
  local options = '--ansi --no-preview --header-lines=' .. (curloaded and '2' or '1')
  fn['fzf#run']({
      source = sessions,
      sink = require'tabline.fzf.sessions'.session_load,
      down = '30%',
      options = options,
    })
end

local function delete_session()
  if mac_no_gnu() then return end
  statusline("Delete Session")
  local _, sessions = require'tabline.fzf.sessions'.sessions_list()
  fn['fzf#run']({
      source = sessions,
      sink = require'tabline.fzf.sessions'.session_delete,
      down = '30%',
      options = '--ansi --header-lines=1 --no-preview'
    })
end

return {
  list_buffers = list_buffers,
  closed_tabs = closed_tabs,
  load_session = load_session,
  delete_session = delete_session,
  save_session = require'tabline.fzf.sessions'.session_save,
  new_session = require'tabline.fzf.sessions'.session_new,
}
