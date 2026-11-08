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

    var map_yy = maparg('yy', 'n', false, true)
    assert_false(empty(map_yy))
    assert_match('log\.YankCommitHash()', map_yy.rhs)
    assert_equal(1, map_yy.buffer)

    var map_go = maparg('go', 'n', false, true)
    assert_false(empty(map_go))
    assert_match('log\.OpenCommitWeb()', map_go.rhs)
    assert_equal(1, map_go.buffer)

    var map_gp = maparg('gp', 'n', false, true)
    assert_false(empty(map_gp))
    assert_match('log\.OpenPullRequestWeb()', map_gp.rhs)
    assert_equal(1, map_gp.buffer)

    var map_a = maparg('a', 'n', false, true)
    assert_false(empty(map_a))
    assert_match('log\.PromptAction()', map_a.rhs)
    assert_equal(1, map_a.buffer)

    assert_equal(2, exists(':GitULogAction'))
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

    var map_c_go = maparg('go', 'n', false, true)
    assert_false(empty(map_c_go))
    assert_match('log\.OpenCommitWeb()', map_c_go.rhs)
    assert_equal(1, map_c_go.buffer)

    var map_c_gp = maparg('gp', 'n', false, true)
    assert_false(empty(map_c_gp))
    assert_match('log\.OpenPullRequestWeb()', map_c_gp.rhs)
    assert_equal(1, map_c_gp.buffer)

    var map_c_a = maparg('a', 'n', false, true)
    assert_false(empty(map_c_a))
    assert_match('log\.PromptAction()', map_c_a.rhs)
    assert_equal(1, map_c_a.buffer)
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

    var map_d_a = maparg('a', 'n', false, true)
    assert_false(empty(map_d_a))
    assert_match('log\.PromptAction()', map_d_a.rhs)
    assert_equal(1, map_d_a.buffer)
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

    var map_x_stage = maparg('<<', 'x', false, true)
    assert_false(empty(map_x_stage))
    assert_match('status\.StageVisual()', map_x_stage.rhs)

    var map_x_unstage = maparg('>>', 'x', false, true)
    assert_false(empty(map_x_unstage))
    assert_match('status\.UnstageVisual()', map_x_unstage.rhs)

    var map_diff = maparg('dd', 'n', false, true)
    assert_false(empty(map_diff))
    assert_match('status\.OpenDiff()', map_diff.rhs)

    var map_patch = maparg('pp', 'n', false, true)
    assert_false(empty(map_patch))
    assert_match('status\.OpenPatchEdit()', map_patch.rhs)

    var map_commit = maparg('cc', 'n', false, true)
    assert_false(empty(map_commit))
    assert_match('commit\.Open()', map_commit.rhs)

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
