vim9script

import autoload 'gitu/commit/parser.vim'

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

    assert_equal(expected, parser.FilterCommitMessage(input))

    var comments_only = [
        '',
        '# Comment line 1',
        '# Comment line 2',
        '   ',
        '',
    ]
    assert_equal([], parser.FilterCommitMessage(comments_only))

    var custom_char_input = [
        'title here',
        '; comment with semicolon',
        '; another comment',
    ]
    assert_equal(['title here'], parser.FilterCommitMessage(custom_char_input, ';'))
enddef

def TestRequiresStagedChanges()
    assert_true(parser.RequiresStagedChanges([]))
    assert_false(parser.RequiresStagedChanges(['--amend']))
    assert_false(parser.RequiresStagedChanges(['-a']))
    assert_false(parser.RequiresStagedChanges(['--all']))
    assert_false(parser.RequiresStagedChanges(['--allow-empty']))
enddef

def TestBuildCommitTemplate()
    var temp_dir = fnamemodify('./tmp/test_commit_template', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/sample.txt'
    writefile(['hello'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add sample.txt')

    try
        var template = parser.BuildCommitTemplate(temp_dir)
        assert_equal('', template[0])
        assert_equal('', template[1])
        assert_match('^# Please enter the commit message', template[2])

        var has_changes_line = false
        for line in template
            if line =~ '^# Changes to be committed:'
                has_changes_line = true
                break
            endif
        endfor
        assert_true(has_changes_line)
    finally
        delete(temp_dir, 'rf')
    endtry
enddef

def TestComplete()
    var all = parser.Complete('', 'GitUCommit ', 11)
    assert_true(index(all, '--amend') >= 0)
    assert_true(index(all, '-a') >= 0)
    assert_true(index(all, '--all') >= 0)

    var filtered = parser.Complete('--am', 'GitUCommit --am', 15)
    assert_equal(['--amend'], filtered)
enddef

def RunAll()
    TestFilterCommitMessage()
    TestRequiresStagedChanges()
    TestBuildCommitTemplate()
    TestComplete()

    if len(v:errors) > 0
        for err in v:errors
            echomsg err
        endfor
        cquit!
    endif
    qall!
enddef

RunAll()
