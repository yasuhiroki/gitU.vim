vim9script

if exists('b:did_ftplugin')
    finish
endif
b:did_ftplugin = 1

import autoload 'gitu/blame/view.vim' as blame

setlocal nowrap
setlocal cursorline
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal foldcolumn=0
setlocal nospell
setlocal nobuflisted

nnoremap <buffer> <silent> q <ScriptCmd>blame.Close()<CR>
nnoremap <buffer> <silent> u <ScriptCmd>blame.Refresh()<CR>
nnoremap <buffer> <silent> <CR> <ScriptCmd>blame.BlameParent()<CR>
nnoremap <buffer> <silent> <C-o> <ScriptCmd>blame.HistoryBack()<CR>
nnoremap <buffer> <silent> <C-i> <ScriptCmd>blame.HistoryForward()<CR>
nnoremap <buffer> <silent> yy <ScriptCmd>blame.YankCommitHash()<CR>
nnoremap <buffer> <silent> go <ScriptCmd>blame.OpenCommitWeb()<CR>
nnoremap <buffer> <silent> gp <ScriptCmd>blame.OpenPullRequestWeb()<CR>

augroup GitUBlameBuffer
    autocmd! * <buffer>
    autocmd BufWipeout <buffer> blame.OnBufWipeout()
augroup END
