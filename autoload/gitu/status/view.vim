vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/status/parser.vim'
import autoload 'gitu/status/patch.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

def LoadStatus(view_id: number)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    git.Run(['status', '--porcelain=v1', '-u', '--branch'], {
        cwd: state.cwd,
        task_key: 'gitu_status_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            if res.status != 0
                var err_lines: list<string> = empty(res.stderr) ? ['Failed to run git status.'] : res.stderr
                buffer.SetLines(cur_state.bufnr, err_lines)
                return
            endif

            var parsed = parser.ParsePorcelain(res.stdout)
            var rendered = parser.RenderStatus(parsed)
            cur_state.line_map = rendered.line_map

            var cur_lnum: number = (cur_state.winid > 0 && win_id2win(cur_state.winid) > 0)
                ? getcurpos(cur_state.winid)[1]
                : 1

            buffer.SetLines(cur_state.bufnr, rendered.lines)

            if cur_state.winid > 0 && win_id2win(cur_state.winid) > 0
                win_execute(cur_state.winid, 'normal! ' .. string(cur_lnum) .. 'G')
            endif
        },
    })
enddef

export def Open()
    var initial_cwd: string = git.ResolveInitialCwd()

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = view.GetKey(view_id)

    tabnew
    t:gitu_view_id = view_id

    var winid: number = win_getid()
    var bufnr: number = buffer.InitCurrentScratch('gitu-status', '[GitU:Status #' .. key .. ']')
    b:gitu_view_id = view_id

    views[key] = {
        id: view_id,
        cwd: initial_cwd,
        bufnr: bufnr,
        winid: winid,
        line_map: {},
    }

    buffer.SetLines(bufnr, ['Loading git status...'])

    git.ResolveRepoRoot(initial_cwd, (root: string, stderr: list<string>) => {
        if !has_key(views, key)
            return
        endif
        if root == ''
            var msg: list<string> = empty(stderr) ? ['Not a git repository.'] : stderr
            buffer.SetLines(views[key].bufnr, msg)
            return
        endif
        views[key].cwd = root
        LoadStatus(view_id)
    })
enddef

export def Refresh()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    LoadStatus(view_id)
enddef

export def RefreshAll()
    for view_id in keys(views)
        LoadStatus(str2nr(view_id))
    endfor
enddef

def StageFiles(key: string, state: dict<any>, files: list<string>)
    if empty(files)
        return
    endif
    git.Run(['add', '--'] + files, {
        cwd: state.cwd,
        task_key: 'gitu_status_action_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            if res.status != 0
                notify.Error('Failed to stage: ' .. join(res.stderr, ' '))
                return
            endif
            Refresh()
        },
    })
enddef

def FallbackReset(key: string, cwd: string, files: list<string>)
    git.Run(['reset', 'HEAD', '--'] + files, {
        cwd: cwd,
        task_key: 'gitu_status_action_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            if res.status != 0
                notify.Error('Failed to unstage: ' .. join(res.stderr, ' '))
                return
            endif
            Refresh()
        },
    })
enddef

def UnstageFiles(key: string, state: dict<any>, files: list<string>)
    if empty(files)
        return
    endif
    # Constraint: git restore --staged fails on initial commit (unborn HEAD);
    # fall back to git reset HEAD.
    git.Run(['restore', '--staged', '--'] + files, {
        cwd: state.cwd,
        task_key: 'gitu_status_action_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            if res.status != 0
                FallbackReset(key, state.cwd, files)
                return
            endif
            Refresh()
        },
    })
enddef

def ApplyFileAction(start_lnum: number, end_lnum: number, action: string)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var files: list<string> = parser.GetSelectedFiles(state, start_lnum, end_lnum, action)
    if action == 'stage'
        StageFiles(key, state, files)
    else
        UnstageFiles(key, state, files)
    endif
enddef

export def StageCurrent()
    var cur_lnum: number = line('.')
    ApplyFileAction(cur_lnum, cur_lnum, 'stage')
enddef

export def UnstageCurrent()
    var cur_lnum: number = line('.')
    ApplyFileAction(cur_lnum, cur_lnum, 'unstage')
enddef

export def StageVisual()
    ApplyFileAction(line("'<"), line("'>"), 'stage')
enddef

export def UnstageVisual()
    ApplyFileAction(line("'<"), line("'>"), 'unstage')
enddef

export def OpenPatchEdit()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var entry: dict<any> = get(state.line_map, string(line('.')), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    var diff_winid: number = get(state, 'diff_winid', -1)
    if diff_winid > 0 && win_id2win(diff_winid) > 0
        win_execute(diff_winid, 'close!')
    endif
    state.diff_winid = -1
    state.diff_bufnr = -1

    patch.Open3Way(state.cwd, entry.file, state.winid, () => {
        Refresh()
    }, () => {
        Refresh()
    })
enddef

export def OpenDiff()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var entry: dict<any> = get(state.line_map, string(line('.')), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    patch.Close3Way()

    var status_height: number = get(g:, 'gitu_status_height', 15)

    var diff_winid: number = get(state, 'diff_winid', -1)
    if diff_winid > 0 && win_id2win(diff_winid) > 0
        win_gotoid(diff_winid)
    else
        botright new
        diff_winid = win_getid()
        state.diff_winid = diff_winid
    endif

    var diff_bufnr: number = buffer.InitCurrentScratch('gitu-diff', printf('[GitU:Diff: %s (%s)]', entry.file, entry.section))
    state.diff_bufnr = diff_bufnr
    nnoremap <buffer> <silent> q <cmd>close<CR>
    buffer.SetLines(diff_bufnr, ['Loading diff...'])

    if status_height > 0 && state.winid > 0 && win_id2win(state.winid) > 0
        setwinvar(state.winid, '&winfixheight', 1)
        win_execute(state.winid, 'resize ' .. string(status_height))
    endif

    var args: list<string> = parser.BuildDiffArgs(entry.section, entry.file)
    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_status_diff_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            # Constraint: git diff exits with 1 when differences are found.
            if res.status != 0 && res.status != 1
                var err_lines = empty(res.stderr) ? ['Failed to load diff.'] : res.stderr
                buffer.SetLines(cur_state.diff_bufnr, err_lines)
                return
            endif

            var lines: list<string> = empty(res.stdout) ? ['(No diff change)'] : res.stdout
            buffer.SetLines(cur_state.diff_bufnr, lines)
            buffer.ResetWindowTop(cur_state.diff_winid)
            if status_height > 0 && cur_state.winid > 0 && win_id2win(cur_state.winid) > 0
                setwinvar(cur_state.winid, '&winfixheight', 1)
                win_execute(cur_state.winid, 'resize ' .. string(status_height))
            endif
        },
    })
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        var state = views[key]
        var diff_winid = get(state, 'diff_winid', -1)
        if diff_winid > 0 && win_id2win(diff_winid) > 0
            win_execute(diff_winid, 'close!')
        endif
        patch.Close3Way()
        git.StopByKey('gitu_status_' .. key)
        git.StopByKey('gitu_status_action_' .. key)
        git.StopByKey('gitu_status_diff_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()
    buffer.CloseTabOrReset()
enddef

view.RegisterRefresher('status', RefreshAll)
