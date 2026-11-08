vim9script

import autoload 'gitu/cmd/proxy.vim' as cmd
import autoload 'gitu/status/view.vim' as status

def WaitFor(Condition: func(): bool, timeout: number = 2000): bool
    var start = reltime()
    while !Condition()
        if reltimefloat(reltime(start)) * 1000.0 > timeout
            return false
        endif
        sleep 20m
    endwhile
    return true
enddef

def TestExecuteEmptyArgs()
    cmd.Execute()
    assert_equal('gitu-status', getbufvar('%', '&filetype'))
    assert_match('^\[GitU:Status #', bufname('%'))
    status.Close()
enddef

def TestExecuteProxyAsync()
    var temp_dir = fnamemodify('./tmp/test_cmd_proxy', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    writefile(['hello'], temp_dir .. '/test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "init"')

    execute 'edit ' .. fnameescape(temp_dir .. '/test.txt')
    try
        cmd.ClearLastResult()
        cmd.Execute('status')

        var ok = WaitFor(() => !empty(cmd.last_result), 3000)
        assert_true(ok, 'Timed out waiting for git status proxy command')
        assert_equal(0, cmd.last_result.status)

        cmd.ClearLastResult()
        cmd.Execute('invalid-subcommand-xyz')

        ok = WaitFor(() => !empty(cmd.last_result), 3000)
        assert_true(ok, 'Timed out waiting for invalid subcommand')
        assert_true(get(cmd.last_result, 'status', 0) != 0)
    finally
        bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestExecuteEmptyArgs()
    TestExecuteProxyAsync()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All cmd proxy tests passed!'
        qall!
    endif
enddef

RunAll()
