local fn = vim.fn
local tbl = require('tabline.table')
local s = require('tabline.setup').settings
local ansi = require('tabline.fzf.ansi')
local g = require('tabline.setup').global
local pers = require('tabline.persist')

local winOs = fn.has('win32') == 1

local sessions_path = s.sessions_dir or fn.stdpath('data') .. '/session'
local sessions_data = fn.stdpath('data') .. '/.tabline_sessions'

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------

local lastmod = function(f)
  return fn.getftime(f)
end
local confirm = function(str)
  return fn.confirm(str, '&Yes\n&No') == 1
end
local obsession = function()
  return fn.exists('g:loaded_obsession') == 1
end

local function sdata() -- Read sessions data file {{{1
  if fn.filereadable(sessions_data) == 0 then
    fn.writefile({ '{}' }, sessions_data)
    return {}
  else
    return fn.json_decode(fn.readfile(sessions_data)[1])
  end
end

local function get_date(f) -- 'date' shell command {{{1
  return fn.strftime("%Y.%m.%d", fn.getftime(f))
end

local function desc(fname, name, data) -- Session description {{{1
  local mark = fname == vim.v.this_session and ansi.green(' [%]  ') or '      '
  local dscr = data[name] or ''
  local time = get_date(fname)
  return string.format(
    '%-30s\t%s%s%s',
    ansi.yellow(name),
    ansi.cyan(time),
    mark,
    dscr
  )
end

-- }}}

-------------------------------------------------------------------------------
-- Module functions
-------------------------------------------------------------------------------

local function sessions_list()
  local lines = {}
  local data = sdata()
  local sessions = fn.globpath(sessions_path, '*', false, true)

  for i, ss in ipairs(sessions) do
    if string.match(ss, '__LAST__') then
      table.remove(sessions, i)
      break
    end
  end

  if not winOs and #sessions > 1 then
    table.sort(sessions, function(a, b)
      return lastmod(a) < lastmod(b)
    end)
    if tbl.index(sessions, vim.v.this_session) then
      table.insert(
        sessions,
        table.remove(sessions, tbl.index(sessions, vim.v.this_session))
      )
    end
  end

  for _, ss in ipairs(sessions) do
    table.insert(lines, 1, desc(ss, fn.fnamemodify(ss, ':t'), data))
  end
  table.insert(lines, 1, 'Session\t\t\tTimestamp\tDescription')
  return tbl.index(sessions, vim.v.this_session), lines
end

-------------------------------------------------------------------------------

local function session_load(line)
  for i = 1, fn.bufnr('$') do
    if fn.getbufvar(i, '&modified') == 1 and fn.buflisted(i) == 1 then
      vim.cmd('redraw!')
      print('Some buffer has unsaved changes')
      return
    end
  end
  local file = sessions_path .. '/' .. string.gsub(line, ' *\t.*', '')
  local this = string.gsub(vim.v.this_session, '\\', '/')

  if fn.filereadable(file) == 0 then
    print("Session file doesn't exist.")
    return
  elseif file == this then
    print('Session is already loaded.')
    return
  end

  if vim.v.this_session ~= '' then
    if confirm('Current session will be unloaded. Confirm?') then
      pers.update_persistence()
    else
      return
    end
  end

  vim.cmd('silent! %bdelete')
  vim.cmd('source ' .. fn.fnameescape(file))
end

------------------------------------------------------------------------------

local function session_save(new)
  if fn.isdirectory(sessions_path) == 0 then
    if confirm('Directory ' .. sessions_path .. ' does not exist, create?') then
      fn.mkdir(sessions_path, 'p')
    else
      return
    end
  end

  local data = sdata()
  local _name = (new or vim.v.this_session == '') and ''
    or fn.fnamemodify(vim.v.this_session, ':t')
  local dscr = data[_name] or ''

  local name = fn.input(
    'Enter a name for ' .. (new and 'the new' or 'this') .. ' session: ',
    _name
  )
  if name == '' then
    return
  end

  data[name] = fn.input('Enter an optional description: ', dscr)

  if
    confirm(string.format('%s session %s?', new and 'New' or 'Save', name))
  then
    if _name ~= '' and name ~= _name then
      pers.update_persistence()
    end

    if new then
      vim.cmd('silent! %bdelete')
      vim.cmd('cd `=$HOME`')
    end

    -- finalize session save
    fn.writefile({ fn.json_encode(data) }, sessions_data)
    local file = sessions_path .. '/' .. name
    if obsession() then
      vim.cmd('silent Obsession ' .. fn.fnameescape(file))
    elseif file ~= '' then
      vim.cmd('silent mksession! ' .. fn.fnameescape(file))
    end
    print("Session '" .. file .. "' has been saved.")
  end
end

local function session_new()
  session_save(true)
end

------------------------------------------------------------------------------

local function session_delete(line)
  local file = sessions_path .. '/' .. string.gsub(line, ' *\t.*', '')

  if
    fn.filereadable(file) == 0 or not confirm('Delete session ' .. file .. '?')
  then
    return
  end

  if obsession() and file == vim.g.this_obsession then
    vim.cmd('silent Obsession!')
  else
    fn.delete(file)
  end

  -- If the current session is the one to be deleted, reset persistence.
  if file == vim.v.this_session then
    g.persist = nil
  end

  print('Session ' .. file .. ' has been deleted')
end

-------------------------------------------------------------------------------

return {
  sessions_list = sessions_list,
  session_load = session_load,
  session_save = session_save,
  session_new = session_new,
  session_delete = session_delete,
}
