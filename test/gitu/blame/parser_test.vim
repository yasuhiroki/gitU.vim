vim9script

import autoload 'gitu/blame/parser.vim'

def TestToRepoRelativePath()
    var temp_dir = fnamemodify('./tmp/test_blame_rel_' .. localtime(), ':p')
    mkdir(temp_dir .. '/sub', 'p')
    var file_path = temp_dir .. '/sub/sample.vim'
    writefile(['vim9script'], file_path)

    try
        var rel = parser.ToRepoRelativePath(temp_dir, file_path)
        assert_equal('sub/sample.vim', rel)
    finally
        delete(temp_dir, 'rf')
    endtry
enddef

def TestParseLinePorcelain()
    var porcelain = [
        '1111111111111111111111111111111111111111 1 1 2',
        'author Alice',
        'author-mail <alice@example.com>',
        'author-time 1700000000',
        'author-tz +0900',
        'committer Alice',
        'committer-mail <alice@example.com>',
        'committer-time 1700000000',
        'committer-tz +0900',
        'summary feat: initial commit',
        'boundary',
        'filename src/main.vim',
        "\tvim9script",
        '2222222222222222222222222222222222222222 2 2 1',
        'author Bob',
        'author-mail <bob@example.com>',
        'author-time 1700086400',
        'author-tz +0900',
        'committer Bob',
        'committer-mail <bob@example.com>',
        'committer-time 1700086400',
        'committer-tz +0900',
        'summary fix: update second line',
        'previous 1111111111111111111111111111111111111111 src/old_main.vim',
        'filename src/main.vim',
        "\tvar x = 42",
    ]

    var res = parser.ParseLinePorcelain(porcelain)
    assert_equal(2, len(res.entries))
    assert_equal(2, len(res.blame_lines))
    assert_equal(2, len(res.file_lines))

    assert_equal('1111111', res.entries[0].short_hash)
    assert_equal('Alice', res.entries[0].author)
    assert_equal('feat: initial commit', res.entries[0].summary)
    assert_equal('', res.entries[0].prev_hash)
    assert_true(res.entries[0].boundary)
    assert_equal('vim9script', res.file_lines[0])
    assert_match('^\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\} feat: initial commit <Alice>$', res.blame_lines[0])

    assert_equal('2222222', res.entries[1].short_hash)
    assert_equal('Bob', res.entries[1].author)
    assert_equal('fix: update second line', res.entries[1].summary)
    assert_equal('1111111111111111111111111111111111111111', res.entries[1].prev_hash)
    assert_equal('src/old_main.vim', res.entries[1].prev_file)
    assert_equal('var x = 42', res.file_lines[1])
    assert_match('^\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\} fix: update second line <Bob>$', res.blame_lines[1])
enddef

def RunAll()
    TestToRepoRelativePath()
    TestParseLinePorcelain()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All blame parser tests passed!'
        qall!
    endif
enddef

RunAll()
