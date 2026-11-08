vim9script

import autoload 'gitu/core/buffer.vim'

def TestInitCurrentScratch()
    enew
    var bufnr = buffer.InitCurrentScratch('gitu-log', 'GitUTestLog')
    assert_equal(bufnr, bufnr('%'))
    assert_equal('nofile', &buftype)
    assert_equal('wipe', &bufhidden)
    assert_false(&swapfile)
    assert_false(&buflisted)
    assert_false(&modifiable)
    assert_equal('gitu-log', &filetype)
    assert_match('GitUTestLog$', bufname(bufnr))
    bwipeout!
enddef

def TestSetLines()
    enew
    var bufnr = buffer.InitCurrentScratch('gitu-diff', 'GitUTestDiff')
    buffer.SetLines(bufnr, ['line 1', 'line 2'])
    assert_equal(['line 1', 'line 2'], getbufline(bufnr, 1, '$'))
    assert_false(getbufvar(bufnr, '&modifiable'))

    buffer.SetLines(bufnr, [])
    assert_equal([''], getbufline(bufnr, 1, '$'))
    bwipeout!
enddef

def RunAll()
    TestInitCurrentScratch()
    TestSetLines()

    if len(v:errors) > 0
        for err in v:errors
            echomsg err
        endfor
        cquit!
    endif
    qall!
enddef

RunAll()
