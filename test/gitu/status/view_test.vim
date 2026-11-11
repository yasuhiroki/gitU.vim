vim9script

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

def TestStatusAutoDiffAndVimdiff()
    var temp_dir = fnamemodify('./tmp/test_status_diff_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    writefile(['line 1', 'line 2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    writefile(['line 1 modified', 'line 2', 'line 3'], file_path)

    var orig_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(temp_dir)
        status.Open()

        var state = status.GetState()
        # Wait for status lines to load and auto-diff to open
        var ok = WaitFor((): bool => len(keys(state.line_map)) > 0 && state.diff_left_winid > 0 && win_id2win(state.diff_left_winid) > 0, 3000)
        assert_true(ok, 'Timed out waiting for status and auto-diff to load')

        # Check that focus remains on the status window
        assert_equal(state.winid, win_getid(), 'Focus should remain on status window')

        # Check side-by-side vimdiff windows
        assert_true(state.diff_left_winid > 0)
        assert_true(state.diff_right_winid > 0)
        assert_true(getwinvar(state.diff_left_winid, '&diff'), 'Left window should be in diff mode')
        assert_true(getwinvar(state.diff_right_winid, '&diff'), 'Right window should be in diff mode')

        # Verify buffer names reflect side-by-side diff
        assert_match('^\[GitU:STAGE\] sample\.txt', bufname(state.diff_left_bufnr))
        assert_match('^\[GitU:WORKTREE\] sample\.txt', bufname(state.diff_right_bufnr))

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

        # Test ToggleOrOpenDiff
        status.ToggleOrOpenDiff()
        assert_equal(-1, state.diff_left_winid, 'Diff should be closed after ToggleOrOpenDiff')

        status.ToggleOrOpenDiff()
        assert_true(state.diff_left_winid > 0, 'Diff should reopen after ToggleOrOpenDiff')

        status.Close()
    finally
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestStatusAutoDiffAndVimdiff()

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
