vim9script

import autoload 'gitu/cmd/complete.vim'

def TestCompleteSubcommands()
    var all = complete.Complete('', 'GitU ', 5)
    assert_true(index(all, 'push') >= 0)
    assert_true(index(all, 'pull') >= 0)
    assert_true(index(all, 'status') >= 0)
    assert_true(index(all, 'checkout') >= 0)
    assert_true(index(all, 'stash') >= 0)

    var pu = complete.Complete('pu', 'GitU pu', 7)
    assert_equal(['pull', 'push'], pu)

    var ch = complete.Complete('ch', 'GitU ch', 7)
    assert_equal(['checkout', 'cherry-pick'], ch)

    var none = complete.Complete('xyz', 'GitU xyz', 8)
    assert_equal([], none)
enddef

def TestCompleteStashAndRemote()
    var stash_all = complete.Complete('', 'GitU stash ', 11)
    assert_equal(['apply', 'branch', 'clear', 'drop', 'list', 'pop', 'push', 'show'], stash_all)

    var stash_po = complete.Complete('po', 'GitU stash po', 13)
    assert_equal(['pop'], stash_po)

    var remote_all = complete.Complete('', 'GitU remote ', 12)
    assert_equal(['add', 'get-url', 'prune', 'remove', 'rename', 'set-head', 'set-url', 'show', 'update'], remote_all)

    var remote_p = complete.Complete('p', 'GitU remote p', 13)
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
        var branches = complete.Complete('', 'GitU checkout ', 14)
        assert_true(index(branches, 'main') >= 0)
        assert_true(index(branches, 'feat-test') >= 0)

        var feat_match = complete.Complete('feat', 'GitU checkout feat', 18)
        assert_equal(['feat-test'], feat_match)
    finally
        bdelete!
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestCompleteSubcommands()
    TestCompleteStashAndRemote()
    TestCompleteBranches()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All cmd complete tests passed!'
        qall!
    endif
enddef

RunAll()
