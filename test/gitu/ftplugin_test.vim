vim9script

import autoload 'gitu/buffer.vim'

def TestLogKeymaps()
    enew
    var nr = buffer.InitCurrentScratch('gitu-log', 'GitUTestKeymapLog')
    runtime ftplugin/gitu-log.vim
    var map_u = maparg('u', 'n', false, true)
    assert_false(empty(map_u))
    assert_match('log\.Refresh()', map_u.rhs)
    assert_equal(1, map_u.buffer)
    bwipeout!
enddef

def TestCommitKeymaps()
    enew
    var nr = buffer.InitCurrentScratch('gitu-commit', 'GitUTestKeymapCommit')
    runtime ftplugin/gitu-commit.vim
    var map_u = maparg('u', 'n', false, true)
    assert_false(empty(map_u))
    assert_match('log\.Refresh()', map_u.rhs)
    assert_equal(1, map_u.buffer)
    bwipeout!
enddef

def TestDiffKeymaps()
    enew
    var nr = buffer.InitCurrentScratch('gitu-diff', 'GitUTestKeymapDiff')
    runtime ftplugin/gitu-diff.vim
    var map_u = maparg('u', 'n', false, true)
    assert_false(empty(map_u))
    assert_match('log\.Refresh()', map_u.rhs)
    assert_equal(1, map_u.buffer)
    bwipeout!
enddef

def RunAll()
    TestLogKeymaps()
    TestCommitKeymaps()
    TestDiffKeymaps()

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
