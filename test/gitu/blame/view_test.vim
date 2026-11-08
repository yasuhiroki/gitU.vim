vim9script

import autoload 'gitu/blame/view.vim' as blame

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

def TestBlameOpenAndHistoryNavigation()
    var temp_dir = fnamemodify('./tmp/test_blame_view_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "TestUser"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/app.py'
    writefile(['line1_v1', 'line2_v1'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add app.py')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 1"')
    var hash1 = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    writefile(['line1_v1', 'line2_v2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add app.py')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 2"')
    var hash2 = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    writefile(['line1_v3', 'line2_v2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add app.py')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "commit 3"')
    var hash3 = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    try
        execute 'edit ' .. fnameescape(file_path)
        setlocal filetype=python
        normal! 1G

        blame.Open()

        # Verify 2-pane layout: left is gitu-blame, right is python file buffer
        assert_equal(2, winnr('$'))
        var state = blame.GetState()
        assert_false(empty(state))
        assert_equal(state.blame_winid, win_getid())
        assert_equal('gitu-blame', getbufvar(state.blame_bufnr, '&filetype'))
        assert_equal('python', getbufvar(state.file_bufnr, '&filetype'))

        var ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for initial blame load')

        var blame_lines = getbufline(state.blame_bufnr, 1, '$')
        var file_lines = getbufline(state.file_bufnr, 1, '$')
        assert_equal(['line1_v3', 'line2_v2'], file_lines)
        assert_match('^' .. hash3[0 : 6], blame_lines[0])
        assert_match('^' .. hash2[0 : 6], blame_lines[1])

        # Press Enter on line 1 (which is at commit 3) -> steps back to commit 2
        normal! 1G
        blame.BlameParent()

        ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for parent blame load (commit 2)')

        blame_lines = getbufline(state.blame_bufnr, 1, '$')
        file_lines = getbufline(state.file_bufnr, 1, '$')
        assert_equal(['line1_v1', 'line2_v2'], file_lines)
        assert_match('^' .. hash1[0 : 6], blame_lines[0])
        assert_match('^' .. hash2[0 : 6], blame_lines[1])

        # Press Enter on line 2 (which is at commit 2) -> steps back to commit 1
        normal! 2G
        blame.BlameParent()

        ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for parent blame load (commit 1)')

        blame_lines = getbufline(state.blame_bufnr, 1, '$')
        file_lines = getbufline(state.file_bufnr, 1, '$')
        assert_equal(['line1_v1', 'line2_v1'], file_lines)
        assert_match('^' .. hash1[0 : 6], blame_lines[0])
        assert_match('^' .. hash1[0 : 6], blame_lines[1])

        # C-o (HistoryBack) -> back to commit 2
        blame.HistoryBack()
        ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for HistoryBack to commit 2')
        assert_equal(['line1_v1', 'line2_v2'], getbufline(state.file_bufnr, 1, '$'))

        # C-o (HistoryBack) -> back to initial view (commit 3)
        blame.HistoryBack()
        ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for HistoryBack to initial commit 3')
        assert_equal(['line1_v3', 'line2_v2'], getbufline(state.file_bufnr, 1, '$'))

        # C-i (HistoryForward) -> forward to commit 2
        blame.HistoryForward()
        ok = WaitFor((): bool => get(blame.GetState(state.id), 'loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for HistoryForward to commit 2')
        assert_equal(['line1_v1', 'line2_v2'], getbufline(state.file_bufnr, 1, '$'))

        # Yank commit hash on line 2 (commit 2)
        normal! 2G
        var yanked = blame.YankCommitHash()
        assert_equal(hash2[0 : 6], yanked)
        assert_equal(hash2[0 : 6], getreg('"'))

        blame.Close()
    finally
        silent! bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    try
        TestBlameOpenAndHistoryNavigation()
    catch
        echomsg 'EXCEPTION: ' .. v:exception .. ' at ' .. v:throwpoint
        cquit!
    endtry

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All blame view tests passed!'
        qall!
    endif
enddef

RunAll()
