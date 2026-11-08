vim9script

if exists('g:loaded_gitu')
    finish
endif
g:loaded_gitu = true

import autoload 'gitu/log.vim'
import autoload 'gitu/status.vim'
import autoload 'gitu/commit.vim'

command! -nargs=* -complete=customlist,log.Complete GitULog log.Open(<f-args>)
command! GitUStatus status.Open()
command! GitU status.Open()
command! -nargs=* -complete=customlist,commit.Complete GitUCommit commit.Open(<f-args>)
