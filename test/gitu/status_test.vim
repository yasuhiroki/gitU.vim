vim9script

import autoload 'gitu/status.vim'

def TestParsePorcelain()
    var input = [
        '## main...origin/main [ahead 1]',
        'M  staged.txt',
        ' M unstaged.txt',
        'MM both.txt',
        'A  added.txt',
        'D  deleted.txt',
        ' D unstaged_del.txt',
        'R  old.txt -> new.txt',
        '?? untracked.txt',
    ]

    var res = status.ParsePorcelain(input)
    assert_equal('main...origin/main [ahead 1]', res.branch)

    # Staged entries
    assert_equal(5, len(res.staged))
    assert_equal({ status: 'M', file: 'staged.txt', raw_file: 'staged.txt' }, res.staged[0])
    assert_equal({ status: 'M', file: 'both.txt', raw_file: 'both.txt' }, res.staged[1])
    assert_equal({ status: 'A', file: 'added.txt', raw_file: 'added.txt' }, res.staged[2])
    assert_equal({ status: 'D', file: 'deleted.txt', raw_file: 'deleted.txt' }, res.staged[3])
    assert_equal({ status: 'R', file: 'new.txt', raw_file: 'old.txt -> new.txt' }, res.staged[4])

    # Unstaged entries
    assert_equal(3, len(res.unstaged))
    assert_equal({ status: 'M', file: 'unstaged.txt' }, res.unstaged[0])
    assert_equal({ status: 'M', file: 'both.txt' }, res.unstaged[1])
    assert_equal({ status: 'D', file: 'unstaged_del.txt' }, res.unstaged[2])

    # Untracked entries
    assert_equal(1, len(res.untracked))
    assert_equal({ status: '?', file: 'untracked.txt' }, res.untracked[0])
enddef

def TestRenderStatus()
    var parsed = {
        branch: 'main',
        staged: [{ status: 'M', file: 'staged.txt' }],
        unstaged: [{ status: 'M', file: 'unstaged.txt' }],
        untracked: [{ status: '?', file: 'untracked.txt' }],
    }

    var rendered = status.RenderStatus(parsed)
    var lines = rendered.lines
    var line_map = rendered.line_map

    assert_equal('Branch: main', lines[0])
    assert_equal('', lines[1])
    assert_equal('Changes to be committed:', lines[2])
    assert_equal('  M  staged.txt', lines[3])
    assert_equal({ section: 'staged', status: 'M', file: 'staged.txt' }, line_map['4'])

    # Clean working tree
    var clean = status.RenderStatus({ branch: 'main', staged: [], unstaged: [], untracked: [] })
    assert_equal('nothing to commit, working tree clean', clean.lines[2])
enddef

def RunAll()
    TestParsePorcelain()
    TestRenderStatus()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All status tests passed!'
        qall!
    endif
enddef

RunAll()
