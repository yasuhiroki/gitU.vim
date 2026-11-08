vim9script

var plugin_root = fnamemodify(expand('<sfile>:p'), ':h:h:h')
execute 'set rtp^=' .. fnameescape(plugin_root)

import autoload 'gitu/cmd.vim'
import autoload 'gitu/status.vim'

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

def TestCompleteSubcommands()
    var all = cmd.Complete('', 'GitU ', 5)
    assert_true(index(all, 'push') >= 0)
    assert_true(index(all, 'pull') >= 0)
    assert_true(index(all, 'status') >= 0)
    assert_true(index(all, 'checkout') >= 0)
    assert_true(index(all, 'stash') >= 0)

    var pu = cmd.Complete('pu', 'GitU pu', 7)
    assert_equal(['pull', 'push'], pu)

    var ch = cmd.Complete('ch', 'GitU ch', 7)
    assert_equal(['checkout', 'cherry-pick'], ch)

    var none = cmd.Complete('xyz', 'GitU xyz', 8)
    assert_equal([], none)
enddef

def TestCompleteStashAndRemote()
    var stash_all = cmd.Complete('', 'GitU stash ', 11)
    assert_equal(['apply', 'branch', 'clear', 'drop', 'list', 'pop', 'push', 'show'], stash_all)

    var stash_po = cmd.Complete('po', 'GitU stash po', 13)
    assert_equal(['pop'], stash_po)

    var remote_all = cmd.Complete('', 'GitU remote ', 12)
    assert_equal(['add', 'get-url', 'prune', 'remove', 'rename', 'set-head', 'set-url', 'show', 'update'], remote_all)

    var remote_p = cmd.Complete('p', 'GitU remote p', 13)
    assert_equal(['prune'], remote_p)
enddef

def TestCompleteBranches()
    var temp_dir = fnamemodify('./tmp/test_cmd_branches', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    writefile(['hello'], temp_dir .. '/dummy.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add dummy.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')
    system('git -C ' .. fnameescape(temp_dir) .. ' branch feat-test')

    execute 'edit ' .. fnameescape(temp_dir .. '/dummy.txt')
    try
        var branches = cmd.Complete('', 'GitU checkout ', 14)
        assert_true(index(branches, 'main') >= 0)
        assert_true(index(branches, 'feat-test') >= 0)

        var feat_match = cmd.Complete('feat', 'GitU checkout feat', 18)
        assert_equal(['feat-test'], feat_match)
    finally
        bdelete!
        delete(temp_dir, 'rf')
    endtry
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

        # Invalid subcommand
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
    TestCompleteSubcommands()
    TestCompleteStashAndRemote()
    TestCompleteBranches()
    TestExecuteEmptyArgs()
    TestExecuteProxyAsync()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All cmd tests passed!'
        qall!
    endif
enddef

RunAll()
