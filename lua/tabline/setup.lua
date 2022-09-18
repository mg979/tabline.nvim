-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local M = { ran_once = false }

M.global = { -- internal tables {{{1
  closed_tabs = {},
  pinned = {},
  valid = {},
  order = { unfiltered = {} },
  recent = { unfiltered = {} },
}

M.variables = { -- internal variables {{{1
  mode = 'auto',
  max_bufs = 10,
  label_style = 'sep',
}

M.settings = {  -- user settings {{{1
  main_cmd_name = 'Tabline',
  filtering = false,
  cwd_badge = true,
  mode_badge = { args = 'args' },
  tabs_badge = { fraction = true, left = true, visibility = {'buffers'} },
  label_style = 'sep',
  show_full_path = false,
  show_unnamed = true,
  clickable_bufline = true,
  max_recent = 10,
  modes = { 'auto', 'buffers', 'args' },
  scratch_label = '[Scratch]',
  unnamed_label = '[Unnamed]',
  mapleader = '<leader><leader>',
  default_mappings = false,
  cd_mappings = false,
  theme = 'default',
  ascii_only = false,
  show_icons = true,
  show_button = false,
  overflow_arrows = false,
  colored_icons = true,
  icon_spacing = '  ',
  separators = {'▎', '▏'}
}

M.icons = { -- icons {{{1
  ['pin'] =      '📌', ['star'] =   '★',   ['book'] =     '📖',  ['lock'] =    '🔒',
  ['hammer'] =   '🔨', ['tick'] =   '✔',   ['cross'] =    '✖',   ['warning'] = '⚠',
  ['menu'] =     '☰',  ['apple'] =  '🍎',  ['linux'] =    '🐧',  ['windows'] = '❖',
  ['git'] =      '',  ['git2'] =   '⎇ ',  ['palette'] =  '🎨',  ['lens'] =    '🔍',
  ['flag'] =     '⚑',  ['flag2'] =  '🏁',  ['fire'] =     '🔥',  ['bomb'] =    '💣',
  ['home'] =     '🏠', ['mail'] =   '✉ ',  ['disk'] =     '🖪 ',  ['arrow'] =   '➤',
  ['terminal'] = '',
  ['tab'] = {"📂", "📁"},
}

M.indicators = { -- indicators {{{1
  ['modified'] = M.settings.ascii_only and '[+]'  or '●',
  ['readonly'] = M.settings.ascii_only and '[RO]' or ' 🔒',
  ['pinned'] = M.settings.ascii_only and   '[^]'  or ' 📌',
  ['close'] = M.settings.ascii_only and    ' X '  or '  ',
}

local MAPPINGS = { -- default mappings {{{1
  -- { mapping, <CR> instead of <Space>, add count }
  ['mode next'] =        { '<F5>', true },
  ['next'] =             { ']b', true, true },
  ['prev'] =             { '[b', true, true },
  ['away'] =             { M.settings.mapleader .. 'a', true },
  ['left'] =             { nil, true, true },
  ['right'] =            { nil, true, true },
  ['filtering!'] =       { M.settings.mapleader .. 'f', true },
  ['fullpath!'] =        { M.settings.mapleader .. '/', true },
  ['close'] =            { M.settings.mapleader .. 'q', true },
  ['pin!'] =             { M.settings.mapleader .. 'p', true },
  ['unpin!'] =           { nil, true },
  ['bufname'] =          { nil, false },
  ['tabname'] =          { nil, false },
  ['buficon'] =          { nil, false },
  ['tabicon'] =          { nil, false },
  ['bufreset'] =         { nil, true },
  ['tabreset'] =         { nil, true },
  ['resetall'] =         { nil, true },
  ['reopen'] =           { M.settings.mapleader .. 'u', true },
  ['closedtabs'] =       { M.settings.mapleader .. 'U', true },
  ['purge'] =            { M.settings.mapleader .. 'x', true },
  ['cleanup'] =          { M.settings.mapleader .. 'X', true },
  ['minimize'] =         { nil, true },
  ['buffers'] =          { M.settings.mapleader .. 'b', true },
  ['session load'] =     { M.settings.mapleader .. 'sl', true },
  ['session new'] =      { M.settings.mapleader .. 'sn', true },
  ['session save'] =     { M.settings.mapleader .. 'ss', true },
  ['session delete'] =   { M.settings.mapleader .. 'sd', true },
}

-- }}}

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------

local function set_mappings(mappings) -- Define mappings {{{1
  local c = M.settings.main_cmd_name
  if c then
    for k, v in pairs(mappings) do
      if v[1] and vim.fn.mapcheck(v[1]) == '' then
        vim.cmd(string.format(
          'nnoremap %s :<c-u>%s %s%s%s',
          v[1],                                 -- mapping
          c,                                    -- :Tabline ex command
          k,                                    -- subcommand
          v[3] and ' <c-r>=v:count1<cr>' or '', -- count
          v[2] and '<cr>' or '<space>'          -- final character
          ))
      end
    end
  end
end

local function set_cd_mappings() -- Define cd mappings {{{1
  local cmd = "lua require'tabline.cd'."
  if not M.settings.cd_mappings then return end
  for _, v in ipairs({ 'cdc', 'cdl', 'cdt', 'cdw' }) do
    if vim.fn.maparg(v) == '' then
      vim.cmd(string.format('nnoremap <silent> %s :<c-u>%s%s()<cr>', v, cmd, v))
    end
  end
  vim.cmd(string.format('nnoremap <silent> cd? :<c-u>%sinfo()<cr>', cmd))
end

local function define_main_cmd() -- Define main command {{{1
  vim.cmd([[
  command! -nargs=1 -complete=customlist,v:lua.require'tabline.cmds'.complete ]] ..
  M.settings.main_cmd_name .. [[ exe "lua require'tabline.cmds'.command(" string(<q-args>) . ")"
  ]])
end

function M.load_theme(reload) -- Load theme {{{1
  if M.settings.theme then
    local themes = require'tabline.themes'
    local theme = themes.themes[M.settings.theme]
    if theme then
      themes.apply(theme, reload)
    else
      local loaded, theme = pcall(require, 'tabline.themes.' .. M.settings.theme)
      if not loaded then
        M.settings.theme = 'default'
        M.load_theme(reload)
        return
      else
        themes.apply(theme.theme(), reload)
      end
    end
  end
  if reload then
    require'tabline.render.icons'.icons = {}
    require'tabline.render.icons'.normalfg = nil
    require'tabline.render.icons'.normalbg = nil
  end
end

-- }}}


-------------------------------------------------------------------------------
-- Module functions
-------------------------------------------------------------------------------

function M.setup(opts)
  if not M.global.buffers then
    require'tabline.bufs'.init_bufs()
  end
  if not M.global.tabs then
    require'tabline.tabs'.init_tabs()
  end
  for k, v in pairs(opts or {}) do
    M.settings[k] = v
  end
  if M.settings.ascii_only then
    M.settings.show_icons = false
    M.settings.separator = ' '
  end

  M.variables.mode = M.settings.modes[1]

  define_main_cmd()
  M.load_theme()
  M.update_label_style()
  M.ran_once = true
  vim.fn['tabline#init']()
end

function M.mappings(maps)
  if not M.ran_once then
    return
  end

  local mappings

  if type(maps) == 'table' then
    for k, v in pairs(maps) do
      if MAPPINGS[k] then
        maps[k] = { v, MAPPINGS[k][2], MAPPINGS[k][3] }
      else
        maps[k] = nil
      end
    end
    if M.settings.default_mappings then
      mappings = vim.tbl_extend('force', MAPPINGS, maps)
    else
      mappings = maps
    end
  elseif maps or M.settings.default_mappings then
    mappings = MAPPINGS
  end

  if mappings then
    set_mappings(mappings)
  end
  if M.settings.cd_mappings then
    set_cd_mappings()
  end
end

function M.update_label_style(force)
  local s, v = M.settings, M.variables
  if type(s.label_style) == 'string' then
    if force then
      s.label_style = force
    end
    v.label_style = s.label_style
  elseif type(s.label_style) == 'table' then
    if force then
      s.label_style[v.mode] = force
    end
    v.label_style = s.label_style[v.mode] or 'sep'
  else
    v.label_style = 'sep'
  end
end

return M
