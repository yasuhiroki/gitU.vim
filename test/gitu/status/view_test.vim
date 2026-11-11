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

def TestStatusOpenDiffFocusAndMove()
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
        var ok = WaitFor((): bool => len(keys(state.line_map)) > 0, 3000)
        assert_true(ok, 'Timed out waiting for status lines')

        var target_lnum = -1
        for [lnum_str, entry] in items(state.line_map)
            if get(entry, 'file', '') == 'sample.txt'
                target_lnum = str2nr(lnum_str)
                break
            endif
        endfor
        assert_true(target_lnum > 0, 'Could not find sample.txt in status line_map')

        cursor(target_lnum, 1)

        # Open diff
        status.OpenDiff()

        # Check that focus remains on the status window!
        assert_equal(state.winid, win_getid(), 'Focus should remain on status window after OpenDiff')

        # Wait for diff to load
        ok = WaitFor((): bool => state.diff_winid > 0 && win_id2win(state.diff_winid) > 0 && len(getbufline(state.diff_bufnr, 1, '$')) > 1, 3000)
        assert_true(ok, 'Timed out waiting for diff output')

        # Add more lines to diff buffer to test scrolling/moving
        setbufvar(state.diff_bufnr, '&modifiable', 1)
        setbufline(state.diff_bufnr, 1, range(1, 20))
        setbufvar(state.diff_bufnr, '&modifiable', 0)

        assert_equal(1, getwininfo(state.diff_winid)[0].topline)

        # Scroll subview down by 5 lines while in status window
        status.MoveSubView(1, 5)
        assert_equal(6, getwininfo(state.diff_winid)[0].topline)
        assert_equal(state.winid, win_getid(), 'Focus should still be on status window')

        # Scroll subview up by 2 lines: topline scrolls to 4, cursor does not move
        status.MoveSubView(-1, 2)
        assert_equal(4, getwininfo(state.diff_winid)[0].topline)
        assert_equal(6, getcurpos(state.diff_winid)[1])

        status.Close()
    finally
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestStatusOpenDiffFocusAndMove()

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
