vim9script

if exists('g:loaded_gitu')
    finish
endif
g:loaded_gitu = true

import autoload 'gitu/log/view.vim' as log
import autoload 'gitu/status/view.vim' as status
import autoload 'gitu/commit/view.vim' as commit
import autoload 'gitu/blame/view.vim' as blame
import autoload 'gitu/gh/view.vim' as gh_view
import autoload 'gitu/cmd/proxy.vim' as cmd

command! -nargs=* -complete=customlist,cmd.Complete GitU cmd.Execute(<f-args>)
command! GitUStatus status.Open()
command! -nargs=* -complete=customlist,log.Complete GitULog log.Open(<f-args>)
command! -nargs=* -complete=customlist,commit.Complete GitUCommit commit.Open(<f-args>)
command! -nargs=? GitUBlame blame.Open(<q-args>)
command! -nargs=* -complete=customlist,gh_view.CompleteIssue GitUIssue gh_view.OpenIssue(<f-args>)
command! -nargs=* -complete=customlist,gh_view.CompletePr GitUPr gh_view.OpenPr(<f-args>)
command! -nargs=* -complete=customlist,gh_view.CompletePr GitUPR gh_view.OpenPr(<f-args>)
command! -nargs=* -complete=customlist,gh_view.CompleteProject GitUProject gh_view.OpenProject(<f-args>)
command! -nargs=* -complete=customlist,gh_view.CompleteGh GitUGh gh_view.Open(<f-args>)
