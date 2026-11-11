vim9script

if exists('b:did_ftplugin')
    finish
endif
b:did_ftplugin = 1

import autoload 'gitu/gh/view.vim' as gh_view

setlocal nowrap
setlocal cursorline
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal foldcolumn=0
setlocal nospell
setlocal nobuflisted

nnoremap <buffer> <silent> q <ScriptCmd>gh_view.Close()<CR>
nnoremap <buffer> <silent> u <ScriptCmd>gh_view.Refresh()<CR>
nnoremap <buffer> <silent> <CR> <ScriptCmd>gh_view.SelectDetailItem()<CR>
nnoremap <buffer> <silent> go <ScriptCmd>gh_view.OpenWeb()<CR>
nnoremap <buffer> <silent> yy <ScriptCmd>gh_view.YankNumber()<CR>
nnoremap <buffer> <silent> <C-j> <ScriptCmd>gh_view.MoveSubView(1, v:count1)<CR>
nnoremap <buffer> <silent> <C-k> <ScriptCmd>gh_view.MoveSubView(-1, v:count1)<CR>
nnoremap <buffer> <silent> <Tab> <ScriptCmd>gh_view.CycleFocus(1)<CR>
nnoremap <buffer> <silent> <S-Tab> <ScriptCmd>gh_view.CycleFocus(-1)<CR>

augroup GitUGhDetailBuffer
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> gh_view.OnDetailCursorMoved(false)
augroup END
