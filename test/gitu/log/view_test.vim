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

def WaitFor(Condition: func(): bool, timeout: number = 3000): bool
    var start = reltime()
    while !Condition()
        if reltimefloat(reltime(start)) * 1000.0 > timeout
            return false
        endif
        sleep 20m
    endwhile
    return true
enddef

def TestLogStreamingLoad()
    var temp_dir = fnamemodify('./tmp/test_log_stream_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    writefile(['first'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 1"')

    writefile(['first', 'second'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 2"')

    try
        execute 'edit ' .. fnameescape(temp_dir .. '/file.txt')
        log.Open()

        var state = log.GetState()
        assert_false(empty(state))

        var ok = WaitFor((): bool => len(filter(getbufline(state.log_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'commit 2') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for streaming log load of commit 2')

        ok = WaitFor((): bool => len(filter(getbufline(state.commit_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'commit 2') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for commit 2 detail')

        ok = WaitFor((): bool => len(filter(getbufline(state.diff_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '+second') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for diff of commit 2')

        log.Close()
    finally
        silent! bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def TestLogUnstagedStagedStash()
    var temp_dir = fnamemodify('./tmp/test_log_special_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    writefile(['base content'], temp_dir .. '/file1.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file1.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 1"')

    # Stash
    writefile(['stash content'], temp_dir .. '/stash.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add stash.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' stash push -m "my test stash"')

    # Staged change
    writefile(['staged content'], temp_dir .. '/staged.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add staged.txt')

    # Unstaged change
    writefile(['base content', 'unstaged edit'], temp_dir .. '/file1.txt')

    try
        execute 'edit ' .. fnameescape(temp_dir .. '/file1.txt')
        log.Open()

        var state = log.GetState()
        assert_false(empty(state))

        var ok = WaitFor((): bool => len(filter(getbufline(state.log_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '[Unstaged changes]') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for [Unstaged changes]')

        ok = WaitFor((): bool => len(filter(getbufline(state.log_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '[Staged changes]') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for [Staged changes]')

        ok = WaitFor((): bool => len(filter(getbufline(state.log_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '[stash@{0}]') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for [stash@{0}]')

        ok = WaitFor((): bool => len(filter(getbufline(state.log_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'commit 1') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for commit 1')

        ok = WaitFor((): bool => len(filter(getbufline(state.commit_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'Unstaged changes') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for unstaged detail')

        ok = WaitFor((): bool => len(filter(getbufline(state.diff_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '+unstaged edit') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for unstaged diff')

        win_execute(state.log_winid, 'normal! 2G0')
        win_execute(state.log_winid, 'call gitu#log#view#OnLogCursorMoved(v:true)')

        ok = WaitFor((): bool => len(filter(getbufline(state.commit_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'Staged changes') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for staged detail')

        ok = WaitFor((): bool => len(filter(getbufline(state.diff_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '+staged content') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for staged diff')

        win_execute(state.log_winid, 'normal! 3G0')
        win_execute(state.log_winid, 'call gitu#log#view#OnLogCursorMoved(v:true)')

        ok = WaitFor((): bool => len(filter(getbufline(state.commit_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'Stash: stash@{0}') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for stash detail')

        ok = WaitFor((): bool => len(filter(getbufline(state.diff_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '+stash content') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for stash diff')

        var stash_line = getbufline(state.log_bufnr, 3)[0]
        var yanked = log.YankCommitHash(stash_line)
        assert_true(len(yanked) >= 7, 'Expected stash hash to be yanked, got: ' .. yanked)

        win_execute(state.log_winid, 'normal! 4G0')
        win_execute(state.log_winid, 'call gitu#log#view#OnLogCursorMoved(v:true)')

        ok = WaitFor((): bool => len(filter(getbufline(state.commit_bufnr, 1, '$'), (_, l: string): bool => stridx(l, 'commit 1') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for commit 1 detail')

        ok = WaitFor((): bool => len(filter(getbufline(state.diff_bufnr, 1, '$'), (_, l: string): bool => stridx(l, '+base content') >= 0)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for commit 1 diff')

        log.Close()
    finally
        silent! bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def TestRebaseInteractiveNoCommit()
    log.Open()
    setbufvar(bufnr('%'), '&modifiable', 1)
    setline('.', '* [Unstaged changes]')
    setbufvar(bufnr('%'), '&modifiable', 0)
    log.RebaseInteractive()
    log.Close()
enddef

def TestMoveDiffView()
    log.Open()
    var state = log.GetState()
    assert_true(state.diff_winid > 0)
    setbufvar(state.diff_bufnr, '&modifiable', 1)
    setbufline(state.diff_bufnr, 1, range(1, 20))
    setbufvar(state.diff_bufnr, '&modifiable', 0)

    assert_equal(1, getwininfo(state.diff_winid)[0].topline)

    log.MoveDiffView(1, 5)
    assert_equal(6, getwininfo(state.diff_winid)[0].topline)

    log.MoveDiffView(-1, 3)
    assert_equal(3, getwininfo(state.diff_winid)[0].topline)
    assert_equal(6, getcurpos(state.diff_winid)[1])

    log.Close()
enddef

def RunAll()
    TestCommitPanelHeight()
    TestYankCommitHash()
    TestLogStreamingLoad()
    TestLogUnstagedStagedStash()
    TestRebaseInteractiveNoCommit()
    TestMoveDiffView()

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
