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
    # Unset commit.template in local repo so it does not inherit global
    system('git -C ' .. fnameescape(temp_dir) .. ' config commit.template ""')

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

def TestCommitTemplateFromConfigAndArgs()
    var temp_dir = fnamemodify('./tmp/test_commit_tmpl_cfg', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var tmpl_file = temp_dir .. '/my_template.txt'
    writefile(['# Title header', 'prefix: '], tmpl_file)
    system('git -C ' .. fnameescape(temp_dir) .. ' config commit.template ' .. fnameescape(tmpl_file))

    writefile(['content'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')

    try
        # From git config
        var tmpl_path = parser.ResolveTemplatePath(temp_dir)
        assert_equal(tmpl_file, tmpl_path)

        var template = parser.BuildCommitTemplate(temp_dir)
        assert_equal('# Title header', template[0])
        assert_equal('prefix: ', template[1])

        # CLI -t override
        var cli_tmpl = temp_dir .. '/cli_tmpl.txt'
        writefile(['cli custom template'], cli_tmpl)
        var cli_path = parser.ResolveTemplatePath(temp_dir, ['-t', cli_tmpl])
        assert_equal(cli_tmpl, cli_path)

        var cli_template = parser.BuildCommitTemplate(temp_dir, ['-t', cli_tmpl])
        assert_equal('cli custom template', cli_template[0])
    finally
        delete(temp_dir, 'rf')
    endtry
enddef

def TestCommentCharAndScissors()
    var temp_dir = fnamemodify('./tmp/test_comment_char', ':p')
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config core.commentChar ";"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config commit.template ""')

    writefile(['content'], temp_dir .. '/file.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' add file.txt')

    try
        assert_equal(';', parser.ResolveCommentChar(temp_dir))
        var template = parser.BuildCommitTemplate(temp_dir, ['-v'])
        assert_match('^; Please enter the commit message', template[2])

        var has_scissors = false
        for line in template
            if line =~ '^; ------------------------ >8 ------------------------'
                has_scissors = true
                break
            endif
        endfor
        assert_true(has_scissors, 'Expected scissors line in verbose commit template')

        # Test filtering with scissors line
        var msg_lines = [
            'feat: add file',
            '',
            'body paragraph',
            '; comment line',
            '; ------------------------ >8 ------------------------',
            'diff --git a/file.txt b/file.txt',
            '+content',
        ]
        var filtered = parser.FilterCommitMessage(msg_lines, ';')
        assert_equal(['feat: add file', '', 'body paragraph'], filtered)
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
    TestCommitTemplateFromConfigAndArgs()
    TestCommentCharAndScissors()
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
