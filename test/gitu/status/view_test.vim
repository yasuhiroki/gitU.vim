vim9script

filetype plugin on

import autoload 'gitu/status/view.vim' as status
import autoload 'gitu/core/buffer.vim'

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

def TestStatusDiffOnDdAndCursorMove()
    var temp_dir = '/tmp/test_status_diff_' .. localtime()
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    var second_path = temp_dir .. '/second.txt'
    writefile(['line 1', 'line 2'], file_path)
    writefile(['second 1', 'second 2'], second_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt second.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    writefile(['line 1 modified', 'line 2', 'line 3'], file_path)
    writefile(['second 1 modified', 'second 2'], second_path)

    var orig_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(temp_dir)
        status.Open()

        var state = status.GetState()
        # Wait for status lines to load
        var ok = WaitFor((): bool => len(keys(state.line_map)) >= 2, 3000)
        assert_true(ok, 'Timed out waiting for status to load')

        # Diff should NOT be open initially on status.Open()
        assert_false(state.diff_enabled, 'diff_enabled should be false on Open()')
        assert_equal(-1, state.diff_left_winid, 'Diff should not open automatically on status.Open()')
        assert_equal(state.winid, win_getid(), 'Focus should be on status window')

        # Press dd (ToggleOrOpenDiff) to open diff
        status.ToggleOrOpenDiff()
        assert_true(state.diff_enabled, 'diff_enabled should be true after dd')
        assert_true(state.diff_left_winid > 0, 'Left diff window should be open after dd')
        assert_true(state.diff_right_winid > 0, 'Right diff window should be open after dd')
        assert_equal(state.winid, win_getid(), 'Focus should remain on status window')
        assert_true(getwinvar(state.diff_left_winid, '&diff'), 'Left window should be in diff mode')
        assert_true(getwinvar(state.diff_right_winid, '&diff'), 'Right window should be in diff mode')

        # Verify buffer names reflect side-by-side diff for sample.txt
        assert_match('^\[GitU:STAGE\] sample\.txt', bufname(state.diff_left_bufnr))
        assert_match('^\[GitU:WORKTREE\] sample\.txt', bufname(state.diff_right_bufnr))

        # Move cursor to second.txt while diff is open -> diff should auto-update
        var second_lnum = -1
        for [l_str, ent] in items(state.line_map)
            if ent.file == 'second.txt'
                second_lnum = str2nr(l_str)
                break
            endif
        endfor
        assert_true(second_lnum > 0, 'second.txt line should exist')
        cursor(second_lnum, 1)
        status.OnStatusCursorMoved()

        var switched_ok = WaitFor((): bool => bufname(state.diff_right_bufnr) =~ 'second\.txt', 3000)
        assert_true(switched_ok, 'Diff should auto-update to second.txt when moving cursor while diff is open')

        # Test scrolling with MoveSubView with different content so diff fold does not collapse lines
        setbufvar(state.diff_left_bufnr, '&modifiable', 1)
        setbufline(state.diff_left_bufnr, 1, range(1, 30))
        setbufvar(state.diff_left_bufnr, '&modifiable', 0)

        setbufvar(state.diff_right_bufnr, '&modifiable', 1)
        setbufline(state.diff_right_bufnr, 1, range(31, 60))
        setbufvar(state.diff_right_bufnr, '&modifiable', 0)

        win_execute(state.diff_left_winid, 'diffupdate')
        win_execute(state.diff_left_winid, 'normal! 1G')
        win_execute(state.diff_right_winid, 'normal! 1G')

        var init_top = getwininfo(state.diff_left_winid)[0].topline
        status.MoveSubView(1, 5)
        assert_equal(init_top + 5, getwininfo(state.diff_left_winid)[0].topline)
        assert_equal(state.winid, win_getid(), 'Focus should remain on status window after MoveSubView')

        status.MoveSubView(-1, 2)
        assert_equal(init_top + 3, getwininfo(state.diff_left_winid)[0].topline)

        # Test CycleFocus
        status.CycleFocus(1)
        assert_equal(state.diff_left_winid, win_getid(), 'CycleFocus should move to left diff')
        status.CycleFocus(1)
        assert_equal(state.diff_right_winid, win_getid(), 'CycleFocus should move to right diff')
        status.CycleFocus(1)
        assert_equal(state.winid, win_getid(), 'CycleFocus should return to status window')

        # Test ToggleOrOpenDiff closes diff and disables auto-diff
        status.ToggleOrOpenDiff()
        assert_false(state.diff_enabled, 'diff_enabled should be false after closing diff with dd')
        assert_equal(-1, state.diff_left_winid, 'Diff should be closed after ToggleOrOpenDiff')

        status.ToggleOrOpenDiff()
        assert_true(state.diff_enabled, 'diff_enabled should be true after reopening diff with dd')
        assert_true(state.diff_left_winid > 0, 'Diff should reopen after ToggleOrOpenDiff')

        status.Close()
    finally
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def TestStatusLargeDiffDelay()
    var temp_dir = '/tmp/test_status_large_' .. localtime()
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var small_path = temp_dir .. '/a_small.txt'
    var large_path = temp_dir .. '/b_large.txt'
    writefile(['small 1', 'small 2'], small_path)
    var init_large: list<string> = []
    for i in range(1, 600)
        add(init_large, 'line ' .. i)
    endfor
    writefile(init_large, large_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add a_small.txt b_large.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    writefile(['small 1 modified', 'small 2'], small_path)
    var mod_large: list<string> = []
    for i in range(1, 600)
        add(mod_large, 'modified line ' .. i)
    endfor
    writefile(mod_large, large_path)

    var orig_cwd = getcwd()
    # Use shorter large delay in test so we can verify both the delayed state and completion quickly
    g:gitu_large_diff_delay = 350
    try
        execute 'cd ' .. fnameescape(temp_dir)
        status.Open()

        var state = status.GetState()
        # Wait for status and pre-fetched diff_stats to load
        var ok = WaitFor((): bool => get(state, 'diff_stats_loaded', false), 3000)
        assert_true(ok, 'Timed out waiting for pre-fetched diff_stats')

        var small_lnum = -1
        var large_lnum = -1
        for [l_str, ent] in items(state.line_map)
            if ent.file == 'a_small.txt'
                small_lnum = str2nr(l_str)
                assert_false(get(ent, 'is_large', false), 'a_small.txt should not be marked is_large')
            elseif ent.file == 'b_large.txt'
                large_lnum = str2nr(l_str)
                assert_true(get(ent, 'is_large', false), 'b_large.txt should be pre-marked is_large')
            endif
        endfor
        assert_true(small_lnum > 0 && large_lnum > 0)

        # Open diff on small file first via dd
        cursor(small_lnum, 1)
        status.ToggleOrOpenDiff()
        assert_match('a_small\.txt', bufname(state.diff_right_bufnr))

        # Move cursor to large file -> should show pending notice first and NOT render full diff immediately
        cursor(large_lnum, 1)
        status.OnStatusCursorMoved()
        sleep 80m
        assert_equal('', state.current_diff_file, 'Full diff should not have rendered yet at 80ms')
        var pending_lines = getbufline(state.diff_right_bufnr, 1, '$')
        assert_match('Large diff detected', get(pending_lines, 0, ''))

        # After delay elapses, full diff should render
        var rendered_ok = WaitFor((): bool => state.current_diff_file == 'b_large.txt', 2000)
        assert_true(rendered_ok, 'Large diff should render after delay')
        assert_equal('modified line 1', getbufline(state.diff_right_bufnr, 1)[0])

        status.Close()
    finally
        unlet! g:gitu_large_diff_delay
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def TestStatusGoToFileAndJumpBack()
    var temp_dir = '/tmp/test_status_gf_' .. localtime()
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/target.txt'
    writefile(['target line 1', 'target line 2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add target.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    writefile(['target line 1 modified'], file_path)

    var orig_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(temp_dir)
        status.Open()

        var state = status.GetState()
        var ok = WaitFor((): bool => len(keys(state.line_map)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for status to load')

        var target_l = -1
        for [l_str, ent] in items(state.line_map)
            if ent.file == 'target.txt'
                target_l = str2nr(l_str)
                break
            endif
        endfor
        assert_true(target_l > 0, 'target.txt line not found')

        cursor(target_l, 1)
        # Open diff with dd first, then trigger cursor timer & refresh right before GoToFile
        status.ToggleOrOpenDiff()
        assert_true(state.diff_left_winid > 0, 'Diff should be open after dd')

        status.OnStatusCursorMoved()
        status.Refresh()
        status.GoToFile()
        assert_equal('target.txt', expand('%:t'), 'GoToFile should open target.txt')

        # Wait past diff timer and async status refresh to ensure diff NEVER opens on top of opened file
        sleep 150m
        var cur_state = status.GetState()
        assert_equal(-1, cur_state.diff_left_winid, 'Diff windows must stay closed while viewing opened file')
        assert_equal(1, winnr('$'), 'Only the opened file window should be visible in tab')
        assert_equal('target.txt', expand('%:t'), 'Current buffer should still be target.txt')

        feedkeys("\<C-o>", 'xt')

        var back_ok = WaitFor((): bool => expand('%:t') =~ '^\[GitU:Status', 3000)
        assert_true(back_ok, 'C-o should return to status screen')
        assert_equal(target_l, line('.'), 'Cursor should return to target.txt line')

        sleep 100m
        assert_equal(-1, status.GetState().diff_left_winid, 'Diff windows should remain closed when returning to status via C-o')

        # Test C-i jumps forward back to target.txt, and C-o returns to status ignoring any diff buffers
        status.JumpForward(1)
        assert_equal('target.txt', expand('%:t'), 'C-i should jump forward to target.txt')

        feedkeys("\<C-o>", 'xt')
        back_ok = WaitFor((): bool => expand('%:t') =~ '^\[GitU:Status', 3000)
        assert_true(back_ok, 'C-o should return to status screen again')

        # Even if a diff buffer was opened or in jumplist, C-o and C-i must ignore diff buffers
        status.ToggleOrOpenDiff()
        assert_true(status.GetState().diff_left_winid > 0)
        status.ToggleOrOpenDiff()
        assert_equal(-1, status.GetState().diff_left_winid)

        # Simulate a stale diff buffer in jumplist before jumping forward to target.txt and back
        var status_bufnr = bufnr('%')
        normal! m'
        enew
        buffer.InitCurrentScratch('gitu-diff', '[GitU:Diff: stale.txt (unstaged)]', 'hide')
        normal! m'
        execute 'buffer ' .. status_bufnr
        cursor(target_l, 1)

        status.JumpBack(1)
        assert_false(status.IsStatusDiffBuffer(bufnr('%')), 'C-o must skip stale diff buffers in jumplist')
        assert_match('^\[GitU:Status', bufname('%'), 'C-o should remain on status buffer after skipping diff buffer')

        status.JumpForward(1)
        assert_false(status.IsStatusDiffBuffer(bufnr('%')), 'C-i must skip stale diff buffers in jumplist')

        status.Close()
    finally
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestStatusDiffOnDdAndCursorMove()
    TestStatusLargeDiffDelay()
    TestStatusGoToFileAndJumpBack()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All status view tests passed!'
        qall!
    endif
enddef

RunAll()
