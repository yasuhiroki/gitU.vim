vim9script

import autoload 'gitu/status/patch.vim'

def TestSaveStageBuffer()
    var temp_dir = fnamemodify('./tmp/test_patch_save_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    writefile(['line 1', 'line 2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    writefile(['line 1 modified', 'line 2'], file_path)

    enew
    var stage_bufnr = bufnr('%')
    setline(1, ['line 1 modified', 'line 2 with staged edit'])

    patch.SaveStageBuffer(temp_dir, 'sample.txt', stage_bufnr)

    var stage_out = trim(system('git -C ' .. fnameescape(temp_dir) .. ' show :sample.txt'))
    var expected = "line 1 modified\nline 2 with staged edit"
    assert_equal(expected, stage_out)
    assert_false(getbufvar(stage_bufnr, '&modified'))

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def TestOpen3Way()
    &lines = 50
    unlet! g:gitu_status_height

    var temp_dir = fnamemodify('./tmp/test_patch_3way_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/test.txt'
    writefile(['base content'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "base"')

    writefile(['worktree content'], file_path)

    enew
    var status_winid = win_getid()

    var callback_called = false
    var save_callback_called = false
    patch.Open3Way(temp_dir, 'test.txt', status_winid, () => {
        callback_called = true
    }, () => {
        save_callback_called = true
    })

    assert_equal(4, winnr('$'))
    assert_equal(15, winheight(status_winid))
    assert_match('\[GitU:STAGE\] test\.txt$', bufname('%'))
    assert_true(patch.IsActive())

    patch.MoveView(1, 1)
    patch.MoveView(-1, 1)

    setline(1, 'staged content')
    write

    assert_true(save_callback_called)

    var staged_out = trim(system('git -C ' .. fnameescape(temp_dir) .. ' show :test.txt'))
    assert_equal('staged content', staged_out)

    patch.Close3Way()
    assert_false(patch.IsActive())
    assert_true(callback_called)
    assert_equal(1, winnr('$'))
    assert_equal(status_winid, win_getid())

    g:gitu_status_height = 20
    patch.Open3Way(temp_dir, 'test.txt', status_winid)
    assert_equal(20, winheight(status_winid))
    patch.Close3Way()
    unlet! g:gitu_status_height

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def Test3WayFiletypeAndSyntax()
    filetype plugin on
    syntax on

    var temp_dir = fnamemodify('./tmp/test_patch_ft_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.py'
    writefile(['def hello():', '    pass'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.py')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "add python"')

    writefile(['def hello():', '    print("hello")'], file_path)

    enew
    var status_winid = win_getid()

    patch.Open3Way(temp_dir, 'sample.py', status_winid)

    assert_equal('python', &filetype)
    assert_equal('[GitU:STAGE] sample.py', bufname('%'))

    wincmd h
    assert_equal('python', &filetype)
    assert_equal('[GitU:HEAD] sample.py', bufname('%'))

    wincmd l
    wincmd l
    assert_equal('python', &filetype)
    assert_match('sample\.py$', bufname('%'))

    patch.Close3Way()

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def TestCloseStageWindow()
    var temp_dir = fnamemodify('./tmp/test_patch_close_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/test.txt'
    writefile(['base content'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "base"')

    execute 'edit ' .. fnameescape(file_path)
    var tab1_winid = win_getid()
    var tab1_bufnr = bufnr('%')

    tabnew
    var status_winid = win_getid()

    var callback_called = false
    patch.Open3Way(temp_dir, 'test.txt', status_winid, () => {
        callback_called = true
    })

    assert_equal(4, winnr('$'))

    close!

    assert_equal(1, winnr('$'))
    assert_equal(status_winid, win_getid())
    assert_true(callback_called)

    tabprevious
    assert_equal(tab1_winid, win_getid())
    assert_equal(tab1_bufnr, bufnr('%'))
    assert_false(&diff)

    tabnext
    tabclose

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def RunAll()
    TestSaveStageBuffer()
    TestOpen3Way()
    Test3WayFiletypeAndSyntax()
    TestCloseStageWindow()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        qall!
    endif
enddef

RunAll()
