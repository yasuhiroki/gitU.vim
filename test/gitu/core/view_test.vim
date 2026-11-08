vim9script

import autoload 'gitu/core/view.vim'

def TestViewIdAndKey()
    assert_equal('42', view.GetKey(42))

    enew
    unlet! b:gitu_view_id
    unlet! t:gitu_view_id
    assert_equal(-1, view.GetCurrentId())

    t:gitu_view_id = 10
    assert_equal(10, view.GetCurrentId())

    b:gitu_view_id = 20
    assert_equal(20, view.GetCurrentId())

    unlet! b:gitu_view_id
    unlet! t:gitu_view_id
    bwipeout!
enddef

def TestRefresherRegistry()
    var refreshed_count = 0
    view.RegisterRefresher('test_view', () => {
        refreshed_count += 1
    })
    view.RefreshAll()
    assert_equal(1, refreshed_count)
enddef

def RunAll()
    TestViewIdAndKey()
    TestRefresherRegistry()

    if len(v:errors) > 0
        for err in v:errors
            echomsg err
        endfor
        cquit!
    endif
    qall!
enddef

RunAll()
