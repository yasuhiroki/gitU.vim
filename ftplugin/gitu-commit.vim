vim9script

if exists('b:did_ftplugin')
    finish
endif
b:did_ftplugin = 1

import autoload 'gitu/log.vim'

setlocal nowrap
setlocal cursorline
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal foldcolumn=0
setlocal nospell
setlocal nobuflisted

nnoremap <buffer> <silent> q <ScriptCmd>log.Close()<CR>
nnoremap <buffer> <silent> u <ScriptCmd>log.Refresh()<CR>
nnoremap <buffer> <silent> a <ScriptCmd>log.PromptAction()<CR>
nnoremap <buffer> <silent> go <ScriptCmd>log.OpenCommitWeb()<CR>
nnoremap <buffer> <silent> gp <ScriptCmd>log.OpenPullRequestWeb()<CR>
nnoremap <buffer> <silent> <CR> <ScriptCmd>log.SelectCommitItem()<CR>
nnoremap <buffer> <silent> <Tab> <ScriptCmd>log.CycleFocus(1)<CR>
nnoremap <buffer> <silent> <S-Tab> <ScriptCmd>log.CycleFocus(-1)<CR>

augroup GitUCommitBuffer
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> log.OnCommitCursorMoved(false)
augroup END
