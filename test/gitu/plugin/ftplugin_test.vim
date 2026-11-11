vim9script

import autoload 'gitu/core/buffer.vim'

def TestLogKeymaps()
    enew
    buffer.InitCurrentScratch('gitu-log', 'GitUTestKeymapLog')
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

    var map_ri = maparg('ri', 'n', false, true)
    assert_false(empty(map_ri))
    assert_match('log\.RebaseInteractive()', map_ri.rhs)
    assert_equal(1, map_ri.buffer)

    var map_cj = maparg('<C-j>', 'n', false, true)
    assert_false(empty(map_cj))
    assert_match('log\.MoveDiffView(1', map_cj.rhs)
    assert_equal(1, map_cj.buffer)

    var map_ck = maparg('<C-k>', 'n', false, true)
    assert_false(empty(map_ck))
    assert_match('log\.MoveDiffView(-1', map_ck.rhs)
    assert_equal(1, map_ck.buffer)

    assert_equal(2, exists(':GitULogAction'))
    bwipeout!
enddef

def TestCommitKeymaps()
    enew
    buffer.InitCurrentScratch('gitu-commit', 'GitUTestKeymapCommit')
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

    var map_c_ri = maparg('ri', 'n', false, true)
    assert_false(empty(map_c_ri))
    assert_match('log\.RebaseInteractive()', map_c_ri.rhs)
    assert_equal(1, map_c_ri.buffer)

    var map_c_cj = maparg('<C-j>', 'n', false, true)
    assert_false(empty(map_c_cj))
    assert_match('log\.MoveDiffView(1', map_c_cj.rhs)
    assert_equal(1, map_c_cj.buffer)

    var map_c_ck = maparg('<C-k>', 'n', false, true)
    assert_false(empty(map_c_ck))
    assert_match('log\.MoveDiffView(-1', map_c_ck.rhs)
    assert_equal(1, map_c_ck.buffer)
    bwipeout!
enddef

def TestDiffKeymaps()
    enew
    buffer.InitCurrentScratch('gitu-diff', 'GitUTestKeymapDiff')
    runtime ftplugin/gitu-diff.vim
    var map_u = maparg('u', 'n', false, true)
    assert_false(empty(map_u))
    assert_match('log\.Refresh()', map_u.rhs)
    assert_equal(1, map_u.buffer)

    var map_d_a = maparg('a', 'n', false, true)
    assert_false(empty(map_d_a))
    assert_match('log\.PromptAction()', map_d_a.rhs)
    assert_equal(1, map_d_a.buffer)

    var map_d_ri = maparg('ri', 'n', false, true)
    assert_false(empty(map_d_ri))
    assert_match('log\.RebaseInteractive()', map_d_ri.rhs)
    assert_equal(1, map_d_ri.buffer)

    var map_d_cj = maparg('<C-j>', 'n', false, true)
    assert_false(empty(map_d_cj))
    assert_match('C-e', map_d_cj.rhs)
    assert_equal(1, map_d_cj.buffer)

    var map_d_ck = maparg('<C-k>', 'n', false, true)
    assert_false(empty(map_d_ck))
    assert_match('C-y', map_d_ck.rhs)
    assert_equal(1, map_d_ck.buffer)
    bwipeout!
enddef

def TestStatusKeymaps()
    enew
    buffer.InitCurrentScratch('gitu-status', 'GitUTestKeymapStatus')
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

    var map_s_cj = maparg('<C-j>', 'n', false, true)
    assert_false(empty(map_s_cj))
    assert_match('status\.MoveSubView(1', map_s_cj.rhs)

    var map_s_ck = maparg('<C-k>', 'n', false, true)
    assert_false(empty(map_s_ck))
    assert_match('status\.MoveSubView(-1', map_s_ck.rhs)

    var map_q = maparg('q', 'n', false, true)
    assert_false(empty(map_q))
    assert_match('status\.Close()', map_q.rhs)

    bwipeout!
enddef

def TestBlameKeymaps()
    enew
    buffer.InitCurrentScratch('gitu-blame', 'GitUTestKeymapBlame')
    runtime ftplugin/gitu-blame.vim

    var map_cr = maparg('<CR>', 'n', false, true)
    assert_false(empty(map_cr))
    assert_match('blame\.BlameParent()', map_cr.rhs)

    var map_co = maparg('<C-o>', 'n', false, true)
    assert_false(empty(map_co))
    assert_match('blame\.HistoryBack()', map_co.rhs)

    var map_ci = maparg('<C-i>', 'n', false, true)
    assert_false(empty(map_ci))
    assert_match('blame\.HistoryForward()', map_ci.rhs)

    var map_q = maparg('q', 'n', false, true)
    assert_false(empty(map_q))
    assert_match('blame\.Close()', map_q.rhs)

    var map_tab = maparg('<Tab>', 'n', false, true)
    assert_false(empty(map_tab))
    assert_match('blame\.CycleFocus(1)', map_tab.rhs)

    var map_stab = maparg('<S-Tab>', 'n', false, true)
    assert_false(empty(map_stab))
    assert_match('blame\.CycleFocus(-1)', map_stab.rhs)

    bwipeout!
enddef

def RunAll()
    TestLogKeymaps()
    TestCommitKeymaps()
    TestDiffKeymaps()
    TestStatusKeymaps()
    TestBlameKeymaps()

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
