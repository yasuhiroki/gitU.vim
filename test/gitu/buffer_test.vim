vim9script

import autoload 'gitu/buffer.vim'

def TestInitCurrentScratch()
    enew
    var nr = buffer.InitCurrentScratch('gitu-log', 'GitUTestLog')
    assert_equal(nr, bufnr('%'))
    assert_equal('nofile', &buftype)
    assert_equal('wipe', &bufhidden)
    assert_false(&swapfile)
    assert_false(&buflisted)
    assert_false(&modifiable)
    assert_equal('gitu-log', &filetype)
    assert_match('GitUTestLog$', bufname(nr))
    bwipeout!
enddef

def TestSetLines()
    enew
    var nr = buffer.InitCurrentScratch('gitu-diff', 'GitUTestDiff')
    buffer.SetLines(nr, ['line 1', 'line 2'])
    assert_equal(['line 1', 'line 2'], getbufline(nr, 1, '$'))
    assert_false(getbufvar(nr, '&modifiable'))

    buffer.SetLines(nr, [])
    assert_equal([''], getbufline(nr, 1, '$'))
    bwipeout!
enddef

def RunAll()
    TestInitCurrentScratch()
    TestSetLines()

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
