vim9script

if exists('g:loaded_gitu')
    finish
endif
g:loaded_gitu = true

import autoload 'gitu/log.vim'

command! -nargs=* -complete=customlist,log.Complete GitULog log.Open(<f-args>)
