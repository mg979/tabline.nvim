local commands, banged
local s = require'tabline.setup'.settings
local g = require'tabline.setup'.global
local v = require'tabline.setup'.variables
local icons = require'tabline.setup'.icons
local h = require'tabline.helpers'
local delbufs = require'tabline.delbufs'
local get_bufs = require'tabline.bufs'.get_bufs
local set_order = require'tabline.bufs'.set_order
local themes = require'tabline.themes'
local fzf = require'tabline.fzf.fzf'
local pers = require("tabline.persist")

local ok, dv = pcall(require, 'nvim-web-devicons')
if not ok then
  dv = nil
end

local function devicon(args)
  local devicons = require'tabline.render.icons'.icons
  return dv and devicons[args[1]] or dv.get_icon(args[1])
end

local function get_icons() return vim.tbl_keys(require("tabline.setup").icons) end

local fn = vim.fn
local update_label_style = require'tabline.setup'.update_label_style

-- vim functions {{{1
local getbufvar = fn.getbufvar
local bufnr = fn.bufnr
local getcwd = fn.getcwd

-- table functions {{{1
local tbl = require'tabline.table'
local remove = table.remove
local insert = table.insert
local index = tbl.index
local filter = tbl.filter
--}}}

-------------------------------------------------------------------------------
-- Main command
-------------------------------------------------------------------------------

local function set_tabline()
    vim.cmd[[set tabline=%!v:lua.require'tabline.tabline'.render()]]
end

local function command(arg)
  local subcmd, bang, args = nil, false, {}
  for w in string.gmatch(arg, '(%S+)') do
    if not subcmd then
      subcmd = w
      if string.find(w, '!', #w, true) then
        bang = true
        subcmd = string.sub(subcmd, 1, #subcmd - 1)
      end
    else
      insert(args, w)
    end
  end
  if not commands[subcmd] and not banged[subcmd] then
    print('Invalid subcommand: ' .. subcmd)
  elseif banged[subcmd] then
    banged[subcmd](bang, args)
  else
    commands[subcmd](args)
  end
end

-------------------------------------------------------------------------------
-- Command completion
-------------------------------------------------------------------------------

local subcmds = { -- {{{1
  'mode', 'info', 'next', 'prev', 'filtering', 'close', 'pin', 'unpin',
  'bufname', 'tabname', 'buficon', 'tabicon', 'bufreset', 'tabreset',
  'reopen', 'resetall', 'purge', 'cleanup', 'minimize', 'fullpath',
  'away', 'left', 'right', 'theme', 'labelstyle', 'filter',
  'buffers', 'closedtabs', 'session', 'button', 'persist',
}

local completion = {  -- {{{1
  ['mode'] = { 'next', 'auto', 'tabs', 'buffers', 'args' },
  ['filtering'] = { 'off' },
  ['fullpath'] = { 'off' },
  ['button'] = { 'off' },
  ['session'] = { 'load', 'new', 'save', 'delete' },
  ['theme'] = (function()
    themes.refresh()
    return themes.available
  end)(),
  ['tabicon'] = get_icons,
  ['buficon'] = get_icons,
  ['labelstyle'] = { 'order', 'bufnr', 'sep' },
}

local function complete(_, c, _)  -- {{{1
  vim.cmd('redraw!')
  local subcmd, arg
  local cmdline = string.sub(c, #s.main_cmd_name + 2)
  for w in string.gmatch(cmdline, '(%w+)') do
    if not subcmd then
      subcmd = w
    elseif not arg then
      arg = w
    else
      return {}
    end
  end
  local res = type(completion[subcmd]) == 'function' and completion[subcmd]() or completion[subcmd]
  if arg and res then
    return filter(res, function(_,str) return string.find(str, '^' .. arg) end)
  elseif subcmd and res then
    return res
  elseif subcmd then
    return filter(
        subcmds, function(_,str) return string.find(str, '^' .. subcmd) end)
  else
    return subcmds
  end
end

-- }}}

-------------------------------------------------------------------------------
-- Subcommands
-------------------------------------------------------------------------------

local function select_tab(cnt) -- Select tab {{{1
  if h.tabs_mode() then
    fn.feedkeys(cnt .. 'gt', 'n')
    return
  end
  local bufs = g.current_buffers
  local b
  if v.mode == 'args' and not h.empty_arglist() then
    b = bufs[math.min(cnt, #fn.argv())]
  elseif v.label_style == 'bufnr' then
    b = cnt
  else
    b = bufs[math.min(cnt, #bufs)]
  end
  vim.cmd('buffer ' .. b)
end

local function select_tab_with_char(cnt) -- Select tab with character {{{1
  if cnt ~= 0 then
    select_tab(cnt)
    return
  end
  local oldstyle, bufs = v.label_style, g.current_buffers
  local seltab, selnr, selaz, _
  v.label_style = 'sel'
  vim.cmd('redrawtabline')
  seltab = fn.nr2char(fn.getchar())
  v.label_style = oldstyle
  vim.cmd('redrawtabline')
  _, _, selnr = string.find(seltab, '(%d)')
  _, _, selaz = string.find(seltab, '([a-z])')
  if h.tabs_mode() then
    if selnr and tonumber(selnr) <= fn.tabpagenr('$') then
      fn.feedkeys(selnr .. 'gt', 'n')
    end
  else
    if selnr and tonumber(selnr) <= #bufs then
      vim.cmd('buffer ' .. bufs[tonumber(selnr)])
    elseif selaz and string.byte(selaz) - 87 <= #bufs then
      vim.cmd('buffer ' .. bufs[string.byte(selaz) - 87])
    end
  end
end

local function next_tab(args) -- Next tab {{{1
  local cnt, last = unpack(args)
  local bufs = get_bufs()
  local max = #bufs
  if last then
    vim.cmd('buffer ' .. bufs[max])
    return
  end
  local cur = index(bufs, bufnr()) or bufs[1]
  local target = (cur - 1 + (cnt or 1)) % max + 1
  vim.cmd('buffer ' .. bufs[target])
end

local function prev_tab(args) -- Prev tab {{{1
  local cnt, first = unpack(args)
  local bufs = get_bufs()
  if first then
    vim.cmd('buffer ' .. bufs[1])
    return
  end
  local max = #bufs
  local cur = index(bufs, bufnr()) or bufs[1]
  local target = cur - (cnt or 1)
  while target <= 0 do
    target = target + max
  end
  vim.cmd('buffer ' .. bufs[target])
end

local function move_left(arg) -- Move current tab N positions to the left {{{1
  local cnt = tonumber(arg[1]) or 1
  if h.tabs_mode() then
    local n = fn.tabpagenr()
    if n == 1 then
      return
    elseif cnt >= n then
      vim.cmd('0tabmove')
    else
      vim.cmd('-' .. cnt .. 'tabmove')
    end
  elseif h.buffers_mode() then
    local bufs = get_bufs()
    local nbufs, cur = #bufs, index(bufs, bufnr())
    if not cur or nbufs < 2 then return end
    local new = cur - cnt
    while new < 1 do
      new = new + nbufs
    end
    insert(bufs, new, remove(bufs, cur))
    set_order(bufs)
    vim.cmd('redrawtabline')
  end
end

local function move_right(arg) -- Move current tab N positions to the right {{{1
  local cnt = tonumber(arg[1]) or 1
  if h.tabs_mode() then
    if fn.tabpagenr() + cnt >= fn.tabpagenr('$') then
      vim.cmd('$tabmove')
    else
      vim.cmd('+' .. cnt .. 'tabmove')
    end
  elseif h.buffers_mode() then
    local bufs = get_bufs()
    local nbufs, cur = #bufs, index(bufs, bufnr())
    if not cur or nbufs < 2 then return end
    local new = cur + cnt
    while new > nbufs do
      new = new - nbufs
    end
    insert(bufs, new, remove(bufs, cur))
    set_order(bufs)
    vim.cmd('redrawtabline')
  end
end

local function away(arg) -- Move tab to last position {{{1
  local nr = #arg > 0 and arg[1] or nil
  if h.tabs_mode() then
    if nr then
      vim.cmd('normal! ' .. nr .. 'gt')
      vim.cmd('$tabmove')
      vim.cmd('normal! ' .. nr .. 'gt')
    else
      local cur = fn.tabpagenr()
      vim.cmd('$tabmove')
      vim.cmd('normal! ' .. cur .. 'gt')
    end
  elseif h.buffers_mode() then
    local bufs = get_bufs()
    local cur = nr or index(bufs, bufnr())
    if #bufs > 0 then
      insert(bufs, remove(bufs, cur))
      set_order(bufs)
    end
    vim.cmd('redrawtabline')
    if cur > 1 then
      vim.cmd('buffer ' .. g.buffers[bufs[cur - 1]].nr)
    else
      vim.cmd('buffer ' .. g.buffers[bufs[1]].nr)
    end
  end
end

local function change_mode(arg) -- Change mode {{{1
  local mode = arg[1]
  if index({ 'auto', 'tabs', 'buffers', 'args' }, mode) then
    v.mode = mode
    update_label_style()
    vim.cmd('redrawtabline')
    return
  elseif mode ~= 'next' or #s.modes < 2 then
    return
  end
  -- try not to reselect the same mode, if old mode was 'auto'
  -- this doesn't seem to work if 'auto' is not the first mode
  local wastab, wasbuf = h.tabs_mode(), h.buffers_mode()
  local old, cur = v.mode, index(s.modes, v.mode)
  if not cur then
    v.mode = s.modes[1]
  else
    v.mode = s.modes[(cur % #s.modes) + 1]
    if old == 'auto' and (h.tabs_mode() == wastab or h.buffers_mode() == wasbuf) then
      v.mode = s.modes[((cur + 1) % #s.modes) + 1]
    end
  end
  update_label_style()
  vim.cmd('redrawtabline')
end

local function toggle_filtering(bang, args) -- Toggle filtering {{{1
  if bang then
    s.filtering = not s.filtering
  else
    s.filtering = args[1] ~= 'off'
  end
  vim.cmd('redraw! | echo "buffer filtering turned ' .. (s.filtering and 'on' or 'off') .. '"')
end

local function fullpath(bang, args) -- Show full path in labels {{{1
  if bang then
    s.show_full_path = not s.show_full_path
  else
    s.show_full_path = args[1] ~= 'off'
  end
  vim.cmd('redrawtabline')
end

local function close() -- Close {{{1
  local cur, alt, bufs = bufnr(), bufnr('#'), g.current_buffers
  vim.o.hidden = true
  if alt ~= -1 and index(bufs, alt) then
    vim.cmd('buffer #')
  elseif #bufs > 1 or not index(bufs, cur) then
    next_tab({1})
  elseif alt > 0 then
    vim.cmd('buffer #')
  else
    vim.cmd('bnext')
  end
  if getbufvar(cur, '&buftype') == 'nofile' then
    vim.cmd('silent! bwipe ' .. cur)
  elseif getbufvar(cur, '&modified') == 0 then
    vim.cmd('bdelete ' .. cur)
  else
    vim.cmd('echo "Modified buffer has been hidden"')
  end
end

local function name_buffer(bang, args) -- Name buffer {{{1
  if ( #args == 0 and not bang ) or not g.buffers[bufnr()] then return end
  local buf = g.buffers[bufnr()]
  if bang then
    buf.name = nil
  else
    if getbufvar(bufnr(), '&buftype') ~= '' then
      buf.special = true
    end
    buf.name = args[1]
  end
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function icon_buffer(bang, args) -- Icon buffer {{{1
  if ( #args == 0 and not bang ) or not g.buffers[bufnr()] then return end
  local buf, icon = g.buffers[bufnr()], nil
  if bang then
    buf.icon = nil
  elseif icons[args[1]] then
    icon = icons[args[1]]
  else
    icon = devicon(args)
    if not icon then return end
  end
  if getbufvar(bufnr(), '&buftype') ~= '' then
    buf.special = true
  end
  buf.icon = icon
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function name_tab(bang, args) -- Name tab {{{1
  if #args == 0 and not bang then return end
  local t = vim.t.tab
  if bang and not t.name then
    return
  elseif bang then
    t.name = false
  else
    t.name = args[1]
  end
  vim.t.tab = t
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function icon_tab(bang, args) -- Icon tab {{{1
  if #args == 0 and not bang then return end
  local t = vim.t.tab
  local icon
  if bang and not t.icon then
    return
  elseif bang then
    icon = nil
  elseif icons[args[1]] then
    icon = icons[args[1]]
  else
    icon = devicon()
    if not icon then return end
  end
  t.icon = icon
  vim.t.tab = t
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function reset_buffer() -- Reset buffer {{{1
  local buf = g.buffers[bufnr()]
  if not buf then return end
  require'tabline.bufs'.add_buf(bufnr())
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function reset_tab() -- Reset tab {{{1
  vim.t.tab = {}
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function reset_all() -- Reset all tabs and buffers {{{1
  for i = 1, fn.tabpagenr('$') do
    fn.settabvar(i, 'tab', {})
  end
  require'tabline.bufs'.init_bufs()
  set_tabline()
  pers.remove_persistance()
end

local function pin_buffer(bang) -- Pin buffer {{{1
  local buf = g.buffers[bufnr()]
  if not buf then return end
  if bang then
    buf.pinned = not buf.pinned
  else
    buf.pinned = true
  end
  vim.cmd('redrawtabline')
  pers.update_persistance()
end

local function unpin_buffer(bang) -- Unpin buffer(s) {{{1
  if bang then
    for _, buf in pairs(g.buffers) do
      buf.pinned = false
    end
  elseif g.buffers[bufnr()] then
    local buf = g.buffers[bufnr()]
    buf.pinned = false
  end
  pers.update_persistance()
  vim.cmd('redrawtabline')
end

local function button(bang, args) -- Show/hide close buttons {{{1
  if bang then
    s.show_button = not s.show_button
  else
    s.show_button = args[1] ~= 'off'
  end
  vim.cmd('redrawtabline')
end

local function reopen() -- Reopen {{{1
  require'tabline.tabs'.reopen()
end

local function purge(wipe) -- Purge {{{1
  local purged, cmd = {}, wipe and 'bwipe' or 'bdelete'

  for _, buf in ipairs(fn.tabpagebuflist(fn.tabpagenr())) do
    local unlisted = fn.buflisted(buf) == 0
    local noma     = fn.getbufvar(buf, "&modifiable") == 0
    local nofile   = fn.getbufvar(buf, "&buftype") ~= '' and fn.getbufvar(buf, "&modified") == 0

    if unlisted or noma or nofile then
      insert(purged, buf)
    end
  end

  if #fn.tabpagebuflist() == 1 and tbl.index(purged, fn.bufnr()) then
    return
  end

  for _, buf in ipairs(purged) do
    vim.cmd(buf .. cmd)
  end
end

local function cleanup(bang) -- Clean up {{{1
  local dn, wn = delbufs.outside_valid_wds(bang)
  local fmt = "Deleted %s buffers%s."
  local wip = wn > 0 and string.format(" (%d wiped)", wn) or ""
  print(string.format(fmt, dn, wip))
end

local function minimize(bang) -- Delete buffers without windows {{{1
  local dn, wn = 0, 0
  if bang then
    dn, wn = delbufs.outside_valid_wds(true)
  end
  dn = dn + delbufs.without_window()
  local fmt = "Deleted %s buffers%s."
  local wip = wn > 0 and string.format(" (%d wiped)", wn) or ""
  print(string.format(fmt, dn, wip))
end

local function info(bang) -- Info {{{1
  if not bang then
    print('--- TABLES ---')
    print('mode: ' .. v.mode)
    print('valid: ' .. vim.inspect(g.valid))
    print('recent: ' .. vim.inspect(s.filtering and g.recent[getcwd()] or g.recent.unfiltered))
    print('order: ' .. vim.inspect(s.filtering and g.order[getcwd()] or g.order.unfiltered))
  else
    print('--- BUFFERS ---')
    for _, val in pairs(g.buffers) do
      print(string.format('%s   %s', val.nr, vim.inspect(val)))
    end
  end
end

local function testspeed() -- Test speed {{{1
  local time = fn.reltime()
  for _ = 1, 1000 do
    vim.cmd('redrawtabline')
  end
  print(
    fn.matchstr(
      fn.reltimestr(fn.reltime(time)), '.*\\..\\{,3}')
      .. ' seconds to redraw 1000 times'
    )
end

local function debug() -- Toggle debug mode {{{1
  s.debug = not s.debug
  print('Debug mode:', s.debug)
end

local function config() -- Configuration buffer {{{1
  fn['tabline#config']()
end

local function labelstyle(arg) -- Labels style {{{1
  update_label_style(arg[1])
  vim.cmd('redrawtabline')
end

local function theme(arg) -- Set theme {{{1
  if not next(arg) then
    print('Current theme: ' .. s.theme)
    return
  end
  themes.refresh()
  if not index(themes.available, arg[1]) then
    print('Theme not available')
  else
    s.theme = arg[1]
    require'tabline.setup'.load_theme(true)
  end
end

local function session(arg) -- Session load/new/save/delete {{{1
  local cmd = ({
    ['load'] = fzf.load_session,
    ['new'] = fzf.new_session,
    ['save'] = fzf.save_session,
    ['delete'] = fzf.delete_session,
  })[arg[1]]
  if cmd then cmd() end
end

local function filter(bang, arg) -- Apply filter for bufferline {{{1
  require'tabline.tabs'.set_filter(arg[1] ~= "" and arg[1] or nil, bang)
  vim.cmd('redrawtabline')
end

local function persist(bang) -- Enable or disable persistance for session {{{1
  if vim.v.this_session == "" then
    print("Not in a session.")
    g.persist = nil
    return
  end
  if bang then
    pers.disable_persistance()
  else
    g.persist = vim.v.this_session
    pers.update_persistance()
  end
end

-- }}}


-------------------------------------------------------------------------------

commands = {  -- {{{1
  ['mode'] = change_mode,
  ['next'] = next_tab,
  ['prev'] = prev_tab,
  ['away'] = away,
  ['left'] = move_left,
  ['right'] = move_right,
  ['close'] = close,
  ['cleanup'] = cleanup,
  ['minimize'] = minimize,
  ['bufreset'] = reset_buffer,
  ['tabreset'] = reset_tab,
  ['reopen'] = reopen,
  ['resetall'] = reset_all,
  ['testspeed'] = testspeed,
  ['debug'] = debug,
  ['config'] = config,
  ['theme'] = theme,
  ['labelstyle'] = labelstyle,
  ['buffers'] = fzf.list_buffers,
  ['closedtabs'] = fzf.closed_tabs,
  ['session'] = session,
  ['persist'] = persist,
}

banged = {  -- {{{1
  ['filtering'] = toggle_filtering,
  ['bufname'] = name_buffer,
  ['tabname'] = name_tab,
  ['buficon'] = icon_buffer,
  ['tabicon'] = icon_tab,
  ['info'] = info,
  ['pin'] = pin_buffer,
  ['unpin'] = unpin_buffer,
  ['purge'] = purge,
  ['fullpath'] = fullpath,
  ['button'] = button,
  ['filter'] = filter,
  ['minimize'] = minimize,
  ['cleanup'] = cleanup,
  ['persist'] = persist,
}

-- }}}

return {
  command = command,
  complete = complete,
  change_mode = change_mode,
  select_tab_with_char = select_tab_with_char,
  away = away,
  next_tab = next_tab,
}
