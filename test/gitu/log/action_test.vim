vim9script

import autoload 'gitu/log/action.vim'

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

def TestRegistryAndResolve()
    var list = action.List()
    assert_true(index(list, 'fixup') >= 0)
    assert_true(index(list, 'rebase') >= 0)

    var fixup_def = action.Get('fixup')
    assert_equal('fixup', fixup_def.name)
    assert_equal('f', fixup_def.key)

    var rebase_def = action.Get('rebase')
    assert_equal('rebase', rebase_def.name)
    assert_equal('r', rebase_def.key)
    assert_equal('ri', rebase_def.alias)

    assert_equal('fixup', action.Resolve('fixup'))
    assert_equal('fixup', action.Resolve('Fixup'))
    assert_equal('fixup', action.Resolve('FIXUP'))
    assert_equal('fixup', action.Resolve('f'))
    assert_equal('fixup', action.Resolve('fi'))
    assert_equal('fixup', action.Resolve('fix'))

    assert_equal('rebase', action.Resolve('rebase'))
    assert_equal('rebase', action.Resolve('Rebase'))
    assert_equal('rebase', action.Resolve('r'))
    assert_equal('rebase', action.Resolve('ri'))
    assert_equal('rebase', action.Resolve('reb'))

    assert_equal('', action.Resolve('unknown_action'))
    assert_equal('', action.Resolve(''))

    var all = action.Complete('', '', 0)
    assert_true(index(all, 'fixup') >= 0)
    assert_equal(['fixup'], action.Complete('fi', '', 2))
    assert_equal([], action.Complete('xyz', '', 3))

    var custom_called = false
    action.Register('test_custom', {
        name: 'test_custom',
        key: 't',
        execute: (ctx: dict<any>) => {
            custom_called = true
        },
    })
    assert_true(index(action.List(), 'test_custom') >= 0)
    assert_equal('test_custom', action.Resolve('t'))
    assert_equal('test_custom', action.Resolve('test_custom'))

    action.Execute('t', {})
    assert_true(custom_called)
enddef

def TestExecuteFixupNoStagedChanges()
    var temp_dir = fnamemodify('./tmp/test_action_no_staged', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    writefile(['first line'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial commit"')

    var hash = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    try
        action.ClearLastActionResult()
        action.Execute('fixup', {
            cwd: temp_dir,
            hash: hash,
            view_id: 1,
        })

        var ok = WaitFor(() => !empty(action.last_action_result), 3000)
        assert_true(ok, 'Timed out waiting for fixup result')
        assert_equal('fixup', action.last_action_result.action)
        assert_equal('No staged changes', action.last_action_result.message)
    finally
        delete(temp_dir, 'rf')
    endtry
enddef

def TestExecuteFixupWithStagedChanges()
    var temp_dir = fnamemodify('./tmp/test_action_staged', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    writefile(['first line'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "feat: initial commit"')

    var hash = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    writefile(['first line', 'second line fix'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')

    try
        action.ClearLastActionResult()
        action.Execute('fixup', {
            cwd: temp_dir,
            hash: hash,
            view_id: 1,
        })

        var ok = WaitFor(() => !empty(action.last_action_result), 3000)
        assert_true(ok, 'Timed out waiting for fixup result')
        assert_equal(0, action.last_action_result.status)
        assert_equal('fixup', action.last_action_result.action)

        var log_out = trim(system('git -C ' .. fnameescape(temp_dir) .. ' log -n 1 --pretty=format:%s'))
        assert_equal('fixup! feat: initial commit', log_out)
    finally
        delete(temp_dir, 'rf')
    endtry
enddef

def TestExecuteRebaseNoHash()
    action.ClearLastActionResult()
    action.Execute('rebase', {
        cwd: getcwd(),
        hash: '',
        view_id: 1,
    })
    assert_equal(-1, action.last_action_result.status)
    assert_equal('rebase', action.last_action_result.action)
enddef

def TestExecuteRebaseInteractive()
    var temp_dir = fnamemodify('./tmp/test_action_rebase', ':p')
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

    var hash = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    var old_seq_editor = get(environ(), 'GIT_SEQUENCE_EDITOR', '')
    try
        setenv('GIT_SEQUENCE_EDITOR', 'true')
        action.ClearLastActionResult()
        action.Execute('rebase', {
            cwd: temp_dir,
            hash: hash,
            view_id: 1,
        })

        var ok = WaitFor(() => !empty(action.last_action_result), 5000)
        assert_true(ok, 'Timed out waiting for rebase result')
        assert_equal(0, action.last_action_result.status)
        assert_equal('rebase', action.last_action_result.action)
    finally
        if old_seq_editor != ''
            setenv('GIT_SEQUENCE_EDITOR', old_seq_editor)
        else
            setenv('GIT_SEQUENCE_EDITOR', v:null)
        endif
        delete(temp_dir, 'rf')
    endtry
enddef

def TestExecuteRebaseInteractiveRoot()
    var temp_dir = fnamemodify('./tmp/test_action_rebase_root', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    writefile(['first'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "root commit"')

    var hash = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))

    var old_seq_editor = get(environ(), 'GIT_SEQUENCE_EDITOR', '')
    try
        setenv('GIT_SEQUENCE_EDITOR', 'true')
        action.ClearLastActionResult()
        action.Execute('rebase', {
            cwd: temp_dir,
            hash: hash,
            view_id: 1,
        })

        var ok = WaitFor(() => !empty(action.last_action_result), 5000)
        assert_true(ok, 'Timed out waiting for root rebase result')
        assert_equal(0, action.last_action_result.status)
        assert_equal('rebase', action.last_action_result.action)
    finally
        if old_seq_editor != ''
            setenv('GIT_SEQUENCE_EDITOR', old_seq_editor)
        else
            setenv('GIT_SEQUENCE_EDITOR', v:null)
        endif
        delete(temp_dir, 'rf')
    endtry
enddef

def RunAll()
    TestRegistryAndResolve()
    TestExecuteFixupNoStagedChanges()
    TestExecuteFixupWithStagedChanges()
    TestExecuteRebaseNoHash()
    TestExecuteRebaseInteractive()
    TestExecuteRebaseInteractiveRoot()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All action tests passed!'
        qall!
    endif
enddef

RunAll()
