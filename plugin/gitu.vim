vim9script

if exists('g:loaded_gitu')
    finish
endif
g:loaded_gitu = true

import autoload 'gitu/log.vim'
import autoload 'gitu/status/view.vim' as status
import autoload 'gitu/commit/view.vim' as commit
import autoload 'gitu/cmd.vim'

command! -nargs=* -complete=customlist,cmd.Complete GitU cmd.Execute(<f-args>)
command! GitUStatus status.Open()
command! -nargs=* -complete=customlist,log.Complete GitULog log.Open(<f-args>)
command! -nargs=* -complete=customlist,commit.Complete GitUCommit commit.Open(<f-args>)
