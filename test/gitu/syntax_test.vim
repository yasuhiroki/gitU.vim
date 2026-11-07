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

def RunAll()
    TestSyntaxDiff()
    TestSyntaxLog()
    TestSyntaxCommit()

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
