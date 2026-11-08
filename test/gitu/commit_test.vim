vim9script

import autoload 'gitu/commit.vim'

def TestFilterCommitMessage()
    var input = [
        '',
        'feat: implement git commit',
        '',
        'detailed description line 1',
        'detailed description line 2',
        '',
        '# Please enter the commit message for your changes.',
        '# Lines starting with ''#'' will be ignored.',
        '#',
        '# Changes to be committed:',
        '#   modified:   file.txt',
        '',
    ]

    var expected = [
        'feat: implement git commit',
        '',
        'detailed description line 1',
        'detailed description line 2',
    ]

    assert_equal(expected, commit.FilterCommitMessage(input))

    # Empty commit message with comments only
    var comments_only = [
        '',
        '# Comment line 1',
        '# Comment line 2',
        '   ',
        '',
    ]
    assert_equal([], commit.FilterCommitMessage(comments_only))

    # Custom comment character
    var custom_char_input = [
        'title here',
        '; comment with semicolon',
        '; another comment',
    ]
    assert_equal(['title here'], commit.FilterCommitMessage(custom_char_input, ';'))
enddef

def TestBuildCommitTemplate()
    var temp_dir = tempname() .. '_gitu_test_commit'
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    writefile(['hello'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt')

    var template = commit.BuildCommitTemplate(temp_dir)
    assert_equal('', template[0])
    assert_equal('', template[1])
    assert_match('^# Please enter the commit message', template[2])

    # Check status comment is present
    var has_changes_line = false
    for line in template
        if line =~ '^# Changes to be committed:'
            has_changes_line = true
            break
        endif
    endfor
    assert_true(has_changes_line)

    delete(temp_dir, 'rf')
enddef

def TestComplete()
    var all = commit.Complete('', 'GitUCommit ', 11)
    assert_true(index(all, '--amend') >= 0)
    assert_true(index(all, '-a') >= 0)
    assert_true(index(all, '--all') >= 0)

    var filtered = commit.Complete('--am', 'GitUCommit --am', 15)
    assert_equal(['--amend'], filtered)
enddef

def RunAll()
    TestFilterCommitMessage()
    TestBuildCommitTemplate()
    TestComplete()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All commit tests passed!'
        qall!
    endif
enddef

RunAll()
