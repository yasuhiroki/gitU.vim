vim9script

syntax enable

def TestSyntaxDiff()
    enew
    setlocal filetype=gitu-diff
    runtime syntax/gitu-diff.vim
    assert_equal('gitu-diff', &filetype)
    assert_equal('gitu-diff', b:current_syntax)
    assert_true(hlID('GitUDiffAdded') > 0)
    assert_true(hlID('GitUDiffRemoved') > 0)
    bwipeout!
enddef

def TestSyntaxLog()
    enew
    setlocal filetype=gitu-log
    runtime syntax/gitu-log.vim
    assert_equal('gitu-log', &filetype)
    assert_equal('gitu-log', b:current_syntax)
    assert_true(hlID('GitULogGraph') > 0)
    assert_true(hlID('GitULogHash') > 0)
    bwipeout!
enddef

def TestSyntaxCommit()
    enew
    setlocal filetype=gitu-commit
    runtime syntax/gitu-commit.vim
    assert_equal('gitu-commit', &filetype)
    assert_equal('gitu-commit', b:current_syntax)
    assert_true(hlID('GitUCommitHeader') > 0)
    assert_true(hlID('GitUCommitStatusAdded') > 0)
    bwipeout!
enddef

def TestSyntaxStatus()
    enew
    setlocal filetype=gitu-status
    runtime syntax/gitu-status.vim
    assert_equal('gitu-status', &filetype)
    assert_equal('gitu-status', b:current_syntax)
    assert_true(hlID('GitUStatusHeaderStaged') > 0)
    assert_true(hlID('GitUStatusSymbolAdded') > 0)
    bwipeout!
enddef

def TestSyntaxBlame()
    enew
    setlocal filetype=gitu-blame
    runtime syntax/gitu-blame.vim
    assert_equal('gitu-blame', &filetype)
    assert_equal('gitu-blame', b:current_syntax)
    assert_true(hlID('GitUBlameHash') > 0)
    assert_true(hlID('GitUBlameAuthor') > 0)
    assert_true(hlID('GitUBlameDate') > 0)
    bwipeout!
enddef

def TestSyntaxGh()
    enew
    setlocal filetype=gitu-gh-list
    runtime syntax/gitu-gh-list.vim
    assert_equal('gitu-gh-list', &filetype)
    assert_equal('gitu-gh-list', b:current_syntax)
    assert_true(hlID('GitUGhNumber') > 0)
    assert_true(hlID('GitUGhStateOpen') > 0)
    bwipeout!

    enew
    setlocal filetype=gitu-gh-detail
    runtime syntax/gitu-gh-detail.vim
    assert_equal('gitu-gh-detail', &filetype)
    assert_equal('gitu-gh-detail', b:current_syntax)
    assert_true(hlID('GitUGhHeader') > 0)
    assert_true(hlID('GitUGhDivider') > 0)
    bwipeout!
enddef

def RunAll()
    TestSyntaxDiff()
    TestSyntaxLog()
    TestSyntaxCommit()
    TestSyntaxStatus()
    TestSyntaxBlame()
    TestSyntaxGh()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        qall!
    endif
enddef

RunAll()
