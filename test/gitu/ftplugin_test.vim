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

def TestStatusKeymaps()
    enew
    var nr = buffer.InitCurrentScratch('gitu-status', 'GitUTestKeymapStatus')
    runtime ftplugin/gitu-status.vim

    var map_u = maparg('u', 'n', false, true)
    assert_false(empty(map_u))
    assert_match('status\.Refresh()', map_u.rhs)

    var map_stage = maparg('<<', 'n', false, true)
    assert_false(empty(map_stage))
    assert_match('status\.StageCurrent()', map_stage.rhs)

    var map_unstage = maparg('>>', 'n', false, true)
    assert_false(empty(map_unstage))
    assert_match('status\.UnstageCurrent()', map_unstage.rhs)

    var map_diff = maparg('dd', 'n', false, true)
    assert_false(empty(map_diff))
    assert_match('status\.OpenDiff()', map_diff.rhs)

    var map_patch = maparg('pp', 'n', false, true)
    assert_false(empty(map_patch))
    assert_match('status\.OpenPatchEdit()', map_patch.rhs)

    var map_q = maparg('q', 'n', false, true)
    assert_false(empty(map_q))
    assert_match('status\.Close()', map_q.rhs)

    bwipeout!
enddef

def RunAll()
    TestLogKeymaps()
    TestCommitKeymaps()
    TestDiffKeymaps()
    TestStatusKeymaps()

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
