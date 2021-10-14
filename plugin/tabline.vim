if !has('nvim')
    finish
endif

augroup tabline
    au!
    au ColorScheme * lua require'tabline.render.icons'.icons = {}
    au ColorScheme * call TablineTheme()
augroup END

fun! TablineTheme() abort
  hi! link TSelect         Pmenu
  hi! link TVisible        Special
  hi! link THidden         Comment
  hi! link TExtra          Visual
  hi! link TSpecial        PmenuSel
  hi! link TFill           Folded
  hi! link TNumSel         TabLineSel
  hi! link TNum            TabLineSel
  hi! link TCorner         Special

  let pat = has('gui_running') || &termguicolors ? 'guibg=\S\+' : 'ctermbg=\S\+'
  let bg = matchstr(execute('hi Normal'), pat)
  exe "lua require'tabline.render.icons'.normalbg = " .. string(bg[1:])
  exe "lua require'tabline.render.icons'.dimfg = " .. string(&bg == 'dark' ? '6c6c6c' : 'a9a9a9')
  try
    exe 'hi TSelectMod'  matchstr(execute('hi Pmenu'), pat) 'guifg=#af0000 gui=bold cterm=bold'
  catch
    hi! link TSelectMod Pmenu
  endtry
  try
    exe 'hi TVisibleMod' matchstr(execute('hi Special'), pat) 'guifg=#af0000 gui=bold cterm=bold'
  catch
    hi! link TVisibleMod Special
  endtry
  try
    exe 'hi THiddenMod'  matchstr(execute('hi Comment'), pat) 'guifg=#af0000 gui=bold cterm=bold'
  catch
    hi! link THiddenMod Comment
  endtry
  try
    exe 'hi TExtraMod'   matchstr(execute('hi Visual'), pat) 'guifg=#af0000 gui=bold cterm=bold'
  catch
    hi! link TExtraMod Visual
  endtry
endfun
call TablineTheme()


lua require'tabline.setup'.setup()

set tabline=%!v:lua.require'tabline'.render()

command! -nargs=1 -complete=customlist,v:lua.require'tabline.cmds'.complete Tabline exe "lua require'tabline.cmds'.command(" . string(<q-args>) . ")"
