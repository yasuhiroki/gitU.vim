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
    assert_true(index(all, '-G') >= 0)
    assert_true(index(all, '-S') >= 0)

    var filtered = log.Complete('--b', 'GitULog --b', 11)
    assert_equal(['--branches'], filtered)
enddef

def TestFormatCommitDetail()
    # Case 1: No empty line before '--- Files ---'
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
    assert_equal(expected1, log.FormatCommitDetail(input1))

    # Case 2: Already one empty line
    assert_equal(expected1, log.FormatCommitDetail(expected1))

    # Case 3: Multiple empty lines before '--- Files ---'
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
    assert_equal(expected1, log.FormatCommitDetail(input3))

    # Case 4: No '--- Files ---'
    var input4 = ['line 1', 'line 2']
    assert_equal(input4, log.FormatCommitDetail(input4))
enddef

def TestNormalizeArgs()
    assert_equal(['-GYankCommitHash'], log.NormalizeArgs(['YankCommitHash']))
    assert_equal(['-Gfoo bar'], log.NormalizeArgs(['foo', 'bar']))
    assert_equal(['--all', '-Gmy_func'], log.NormalizeArgs(['--all', 'my_func']))
    assert_equal(['-n', '20', '-Gmy_func'], log.NormalizeArgs(['-n', '20', 'my_func']))
    assert_equal(['--branches'], log.NormalizeArgs(['--branches']))
    assert_equal(['-G', 'existing'], log.NormalizeArgs(['-G', 'existing']))
    assert_equal(['-Gexisting'], log.NormalizeArgs(['-Gexisting']))
    assert_equal(['-S', 'pickaxe'], log.NormalizeArgs(['-S', 'pickaxe']))
    assert_equal([], log.NormalizeArgs([]))
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
    assert_equal(expected, log.StripTrailingWhitespace(input))
enddef

def TestCommitPanelHeight()
    &lines = 50
    unlet! g:gitu_commit_height

    log.Open()
    var tab_nr: number = tabpagenr()
    var commit_winid: number = -1
    for winnr in range(1, tabpagewinnr(tab_nr, '$'))
        var wid: number = win_getid(winnr, tab_nr)
        if getwinvar(wid, '&filetype') == 'gitu-commit'
            commit_winid = wid
            break
        endif
    endfor
    assert_true(commit_winid > 0)
    assert_equal(15, winheight(commit_winid))
    log.Close()

    g:gitu_commit_height = 20
    log.Open()
    tab_nr = tabpagenr()
    commit_winid = -1
    for winnr in range(1, tabpagewinnr(tab_nr, '$'))
        var wid: number = win_getid(winnr, tab_nr)
        if getwinvar(wid, '&filetype') == 'gitu-commit'
            commit_winid = wid
            break
        endif
    endfor
    assert_true(commit_winid > 0)
    assert_equal(20, winheight(commit_winid))
    log.Close()
    unlet! g:gitu_commit_height
enddef

def TestYankCommitHash()
    setreg('"', 'initial')
    var res = log.YankCommitHash('* 0d3ed9f docs: update README')
    assert_equal('0d3ed9f', res)
    assert_equal('0d3ed9f', getreg('"'))

    # Empty / non-commit line
    setreg('"', 'preserved')
    var empty_res = log.YankCommitHash('| /')
    assert_equal('', empty_res)
    assert_equal('preserved', getreg('"'))

    # Clipboard sync
    var orig_cb = &clipboard
    &clipboard = 'unnamed,unnamedplus'
    log.YankCommitHash('* a1b2c3d feat: something')
    assert_equal('a1b2c3d', getreg('"'))
    assert_equal('a1b2c3d', getreg('*'))
    assert_equal('a1b2c3d', getreg('+'))
    &clipboard = orig_cb

    # From current buffer line
    enew
    setline(1, '* 9876543 fix: bug')
    assert_equal('9876543', log.YankCommitHash())
    assert_equal('9876543', getreg('"'))
    bwipeout!
enddef

def RunAll()
    TestExtractCommitHash()
    TestExtractFilePath()
    TestComplete()
    TestStripTrailingWhitespace()
    TestCommitPanelHeight()
    TestYankCommitHash()
    TestFormatCommitDetail()
    TestNormalizeArgs()

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
