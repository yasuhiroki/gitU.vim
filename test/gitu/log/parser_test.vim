vim9script

import autoload 'gitu/log/parser.vim'

def TestExtractCommitHash()
    assert_equal('0d3ed9f', parser.ExtractCommitHash('* 0d3ed9f docs: update README'))
    assert_equal('f0c20ce', parser.ExtractCommitHash('* | f0c20ce Initial commit'))
    assert_equal('1a2b3c4', parser.ExtractCommitHash('| * 1a2b3c4 (HEAD -> feature) add feature'))
    assert_equal('aabbccdd1234567890abcdef1234567890abcdef', parser.ExtractCommitHash('* aabbccdd1234567890abcdef1234567890abcdef full sha'))
    assert_equal('', parser.ExtractCommitHash('|/'))
    assert_equal('', parser.ExtractCommitHash('| \\'))
    assert_equal('', parser.ExtractCommitHash(''))
enddef

def TestExtractFilePath()
    assert_equal('README.md', parser.ExtractFilePath("M\tREADME.md"))
    assert_equal('autoload/gitu/log.vim', parser.ExtractFilePath("A\tautoload/gitu/log.vim"))
    assert_equal('deleted.txt', parser.ExtractFilePath("D\tdeleted.txt"))
    assert_equal('new_name.txt', parser.ExtractFilePath("R100\told_name.txt\tnew_name.txt"))
    assert_equal('copied.txt', parser.ExtractFilePath("C100\tsrc.txt\tcopied.txt"))
    assert_equal('', parser.ExtractFilePath('Author: test'))
    assert_equal('', parser.ExtractFilePath('--- Files ---'))
enddef

def TestComplete()
    var all = parser.Complete('', 'GitULog ', 8)
    assert_true(index(all, '--all') >= 0)
    assert_true(index(all, '--branches') >= 0)
    assert_true(index(all, '-G') >= 0)
    assert_true(index(all, '-S') >= 0)

    var filtered = parser.Complete('--b', 'GitULog --b', 11)
    assert_equal(['--branches'], filtered)
enddef

def TestFormatCommitDetail()
    var input1 = [
        'Commit: 1234567',
        'Author: test',
        '',
        'commit message title',
        '--- Files ---',
        "M\tsample.txt"
    ]
    var expected1 = [
        'Commit: 1234567',
        'Author: test',
        '',
        'commit message title',
        '',
        '--- Files ---',
        "M\tsample.txt"
    ]
    assert_equal(expected1, parser.FormatCommitDetail(input1))
    assert_equal(expected1, parser.FormatCommitDetail(expected1))

    var input3 = [
        'Commit: 1234567',
        'Author: test',
        '',
        'commit message title',
        '',
        '   ',
        '',
        '--- Files ---',
        "M\tsample.txt"
    ]
    assert_equal(expected1, parser.FormatCommitDetail(input3))

    var input4 = ['line 1', 'line 2']
    assert_equal(input4, parser.FormatCommitDetail(input4))
enddef

def TestNormalizeArgs()
    assert_equal(['-GYankCommitHash'], parser.NormalizeArgs(['YankCommitHash']))
    assert_equal(['-Gfoo bar'], parser.NormalizeArgs(['foo', 'bar']))
    assert_equal(['--all', '-Gmy_func'], parser.NormalizeArgs(['--all', 'my_func']))
    assert_equal(['-n', '20', '-Gmy_func'], parser.NormalizeArgs(['-n', '20', 'my_func']))
    assert_equal(['--branches'], parser.NormalizeArgs(['--branches']))
    assert_equal(['-G', 'existing'], parser.NormalizeArgs(['-G', 'existing']))
    assert_equal(['-Gexisting'], parser.NormalizeArgs(['-Gexisting']))
    assert_equal(['-S', 'pickaxe'], parser.NormalizeArgs(['-S', 'pickaxe']))
    assert_equal([], parser.NormalizeArgs([]))
enddef

def TestStripTrailingWhitespace()
    var input = [
        '* 1234567 feat: commit   ',
        '| \\  ',
        "|/ \t ",
        'clean line',
        '',
        '   ',
    ]
    var expected = [
        '* 1234567 feat: commit',
        '| \\',
        '|/',
        'clean line',
        '',
        '',
    ]
    assert_equal(expected, parser.StripTrailingWhitespace(input))
enddef

def RunAll()
    TestExtractCommitHash()
    TestExtractFilePath()
    TestComplete()
    TestFormatCommitDetail()
    TestNormalizeArgs()
    TestStripTrailingWhitespace()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All log parser tests passed!'
        qall!
    endif
enddef

RunAll()
