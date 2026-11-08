vim9script

import autoload 'gitu/commit/view.vim' as commit
import autoload 'gitu/cmd/proxy.vim' as cmd

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

def TestCommitWriteAndQuit()
    var temp_dir = fnamemodify('./tmp/test_commit_wq_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    writefile(['first line'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')

    try
        execute 'edit ' .. fnameescape(temp_dir .. '/file.txt')
        commit.Open()

        var ok = WaitFor((): bool => &filetype == 'gitcommit', 3000)
        assert_true(ok, 'Timed out waiting for gitcommit editor tab')

        setline(1, 'feat: add file.txt')
        wq

        ok = WaitFor((): bool => {
            var log_out = system('git -C ' .. fnameescape(temp_dir) .. ' log --oneline')
            return stridx(log_out, 'feat: add file.txt') >= 0
        }, 3000)
        assert_true(ok, 'Expected commit to be created after :wq')
        sleep 100m
    finally
        silent! bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def TestGitUCommitProxy()
    var temp_dir = fnamemodify('./tmp/test_gitu_commit_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    writefile(['hello proxy'], temp_dir .. '/hello.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add hello.txt')

    try
        execute 'edit ' .. fnameescape(temp_dir .. '/hello.txt')
        cmd.Execute('commit')

        var ok = WaitFor((): bool => &filetype == 'gitcommit', 3000)
        assert_true(ok, 'Expected :GitU commit to open commit editor tab')

        setline(1, 'feat: via gitu commit')
        wq

        ok = WaitFor((): bool => {
            var log_out = system('git -C ' .. fnameescape(temp_dir) .. ' log --oneline')
            return stridx(log_out, 'feat: via gitu commit') >= 0
        }, 3000)
        assert_true(ok, 'Expected commit to be created from :GitU commit after :wq')
        sleep 100m
    finally
        silent! bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestCommitWriteAndQuit()
    TestGitUCommitProxy()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All commit view tests passed!'
        qall!
    endif
enddef

RunAll()
