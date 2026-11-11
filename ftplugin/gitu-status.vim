vim9script

if exists('b:did_ftplugin')
    finish
endif
b:did_ftplugin = 1

import autoload 'gitu/status/view.vim' as status
import autoload 'gitu/commit/view.vim' as commit

setlocal nowrap
setlocal cursorline
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal foldcolumn=0
setlocal nospell
setlocal nobuflisted

nnoremap <buffer> <silent> q <ScriptCmd>status.Close()<CR>
nnoremap <buffer> <silent> u <ScriptCmd>status.Refresh()<CR>
nnoremap <buffer> <silent> << <ScriptCmd>status.StageCurrent()<CR>
nnoremap <buffer> <silent> >> <ScriptCmd>status.UnstageCurrent()<CR>
xnoremap <buffer> <silent> << <Esc><ScriptCmd>status.StageVisual()<CR>
xnoremap <buffer> <silent> >> <Esc><ScriptCmd>status.UnstageVisual()<CR>
nnoremap <buffer> <silent> dd <ScriptCmd>status.OpenDiff()<CR>
nnoremap <buffer> <silent> pp <ScriptCmd>status.OpenPatchEdit()<CR>
nnoremap <buffer> <silent> cc <ScriptCmd>commit.Open()<CR>
nnoremap <buffer> <silent> <C-j> <ScriptCmd>status.MoveSubView(1, v:count1)<CR>
nnoremap <buffer> <silent> <C-k> <ScriptCmd>status.MoveSubView(-1, v:count1)<CR>

augroup GitUStatusBuffer
    autocmd! * <buffer>
    autocmd BufWipeout <buffer> status.OnBufWipeout()
augroup END
