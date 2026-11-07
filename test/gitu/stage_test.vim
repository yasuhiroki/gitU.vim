vim9script

import autoload 'gitu/stage.vim'

def TestSaveStageBuffer()
    var temp_dir = tempname() .. '_gitu_test_repo'
    mkdir(temp_dir, 'p')

    # Initialize a temporary git repository
    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    writefile(['line 1', 'line 2'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "initial"')

    # Modify the working file
    writefile(['line 1 modified', 'line 2'], file_path)

    # Simulate staging buffer with new content
    enew
    var stage_bufnr = bufnr('%')
    setline(1, ['line 1 modified', 'line 2 with staged edit'])

    stage.SaveStageBuffer(temp_dir, 'sample.txt', stage_bufnr)

    # Check that stage content in git index matches the buffer
    var stage_out = trim(system('git -C ' .. fnameescape(temp_dir) .. ' show :sample.txt'))
    var expected = "line 1 modified\nline 2 with staged edit"
    assert_equal(expected, stage_out)
    assert_false(getbufvar(stage_bufnr, '&modified'))

    bwipeout!
    delete(temp_dir, 'rf')
enddef

def RunAll()
    TestSaveStageBuffer()

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
