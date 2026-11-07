vim9script

import autoload 'gitu/stage.vim'

def TestSaveStageBuffer()
    var temp_dir = tempname() .. '_gitu_test_repo'
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

    stage.SaveStageBuffer(temp_dir, 'sample.txt', stage_bufnr)

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

    var temp_dir = tempname() .. '_gitu_test_3way'
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
    stage.Open3Way(temp_dir, 'test.txt', status_winid, () => {
        callback_called = true
    })

    # Should have 4 windows in total (status on top, 3 panels on bottom)
    assert_equal(4, winnr('$'))
    assert_equal(15, winheight(status_winid))

    # Active window should be the center STAGE panel
    assert_match('\[GitU:STAGE\] test\.txt$', bufname('%'))

    # Edit STAGE buffer and save
    setline(1, 'staged content')
    write

    var staged_out = trim(system('git -C ' .. fnameescape(temp_dir) .. ' show :test.txt'))
    assert_equal('staged content', staged_out)

    # Close 3way
    stage.Close3Way()
    assert_true(callback_called)
    assert_equal(1, winnr('$'))
    assert_equal(status_winid, win_getid())

    # Test custom status height
    g:gitu_status_height = 20
    stage.Open3Way(temp_dir, 'test.txt', status_winid)
    assert_equal(20, winheight(status_winid))
    stage.Close3Way()
    unlet! g:gitu_status_height

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def Test3WayFiletypeAndSyntax()
    filetype plugin on
    syntax on

    var temp_dir = tempname() .. '_gitu_test_ft'
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

    stage.Open3Way(temp_dir, 'sample.py', status_winid)

    assert_equal('python', &filetype)
    assert_equal('[GitU:STAGE] sample.py', bufname('%'))

    wincmd h
    assert_equal('python', &filetype)
    assert_equal('[GitU:HEAD] sample.py', bufname('%'))

    wincmd l
    wincmd l
    assert_equal('python', &filetype)
    assert_match('sample\.py$', bufname('%'))

    stage.Close3Way()

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def RunAll()
    TestSaveStageBuffer()
    TestOpen3Way()
    Test3WayFiletypeAndSyntax()

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
