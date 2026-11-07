vim9script

import autoload 'gitu/log.vim'

def TestExtractCommitHash()
    # Direct commit without graph prefix
    assert_equal('0d3ed9f', log.ExtractCommitHash('* 0d3ed9f docs: update README'))
    # Graph with branch connector lines
    assert_equal('f0c20ce', log.ExtractCommitHash('* | f0c20ce Initial commit'))
    assert_equal('1a2b3c4', log.ExtractCommitHash('| * 1a2b3c4 (HEAD -> feature) add feature'))
    assert_equal('aabbccdd1234567890abcdef1234567890abcdef', log.ExtractCommitHash('* aabbccdd1234567890abcdef1234567890abcdef full sha'))
    # Non-commit lines (graph connectors only)
    assert_equal('', log.ExtractCommitHash('|/'))
    assert_equal('', log.ExtractCommitHash('| \\'))
    assert_equal('', log.ExtractCommitHash(''))
enddef

def TestExtractFilePath()
    assert_equal('README.md', log.ExtractFilePath("M\tREADME.md"))
    assert_equal('autoload/gitu/log.vim', log.ExtractFilePath("A\tautoload/gitu/log.vim"))
    assert_equal('deleted.txt', log.ExtractFilePath("D\tdeleted.txt"))
    assert_equal('new_name.txt', log.ExtractFilePath("R100\told_name.txt\tnew_name.txt"))
    assert_equal('copied.txt', log.ExtractFilePath("C100\tsrc.txt\tcopied.txt"))
    assert_equal('', log.ExtractFilePath('Author: test'))
    assert_equal('', log.ExtractFilePath('--- Files ---'))
enddef

def TestComplete()
    var all = log.Complete('', 'GitULog ', 8)
    assert_true(index(all, '--all') >= 0)
    assert_true(index(all, '--branches') >= 0)

    var filtered = log.Complete('--b', 'GitULog --b', 11)
    assert_equal(['--branches'], filtered)
enddef

def RunAll()
    TestExtractCommitHash()
    TestExtractFilePath()
    TestComplete()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All log tests passed!'
        qall!
    endif
enddef

RunAll()
