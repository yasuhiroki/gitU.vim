vim9script

import autoload 'gitu/log/view.vim' as log

def TestCommitPanelHeight()
    &lines = 50
    unlet! g:gitu_commit_height

    log.Open()
    var tab_nr: number = tabpagenr()
    var commit_winid: number = -1
    for winnr in range(1, tabpagewinnr(tab_nr, '$'))
        var wid: number = win_getid(winnr, tab_nr)
        if getwinvar(wid, '&filetype') == 'gitu-commit'
            commit_winid = wid
            break
        endif
    endfor
    assert_true(commit_winid > 0)
    assert_equal(15, winheight(commit_winid))
    log.Close()

    g:gitu_commit_height = 20
    log.Open()
    tab_nr = tabpagenr()
    commit_winid = -1
    for winnr in range(1, tabpagewinnr(tab_nr, '$'))
        var wid: number = win_getid(winnr, tab_nr)
        if getwinvar(wid, '&filetype') == 'gitu-commit'
            commit_winid = wid
            break
        endif
    endfor
    assert_true(commit_winid > 0)
    assert_equal(20, winheight(commit_winid))
    log.Close()
    unlet! g:gitu_commit_height
enddef

def TestYankCommitHash()
    setreg('"', 'initial')
    var res = log.YankCommitHash('* 0d3ed9f docs: update README')
    assert_equal('0d3ed9f', res)
    assert_equal('0d3ed9f', getreg('"'))

    setreg('"', 'preserved')
    var empty_res = log.YankCommitHash('| /')
    assert_equal('', empty_res)
    assert_equal('preserved', getreg('"'))

    var orig_cb = &clipboard
    &clipboard = 'unnamed,unnamedplus'
    log.YankCommitHash('* a1b2c3d feat: something')
    assert_equal('a1b2c3d', getreg('"'))
    assert_equal('a1b2c3d', getreg('*'))
    assert_equal('a1b2c3d', getreg('+'))
    &clipboard = orig_cb

    enew
    setline(1, '* 9876543 fix: bug')
    assert_equal('9876543', log.YankCommitHash())
    assert_equal('9876543', getreg('"'))
    bwipeout!
enddef

def RunAll()
    TestCommitPanelHeight()
    TestYankCommitHash()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All log view tests passed!'
        qall!
    endif
enddef

RunAll()
