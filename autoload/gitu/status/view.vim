vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/status/parser.vim'
import autoload 'gitu/status/patch.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

def FindFirstFileLnum(line_map: dict<dict<any>>): number
    var lnums = sort(map(keys(line_map), (_, k: string): number => str2nr(k)))
    return empty(lnums) ? -1 : lnums[0]
enddef

def GetBlobLines(cwd: string, rev_path: string): list<string>
    var out = system('git -C ' .. fnameescape(cwd) .. ' show ' .. fnameescape(rev_path))
    if v:shell_error != 0
        return ['']
    endif
    var lines = split(out, "\n")
    return empty(lines) ? [''] : lines
enddef

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

            var first_file_lnum = FindFirstFileLnum(rendered.line_map)
            var target_lnum = cur_lnum
            if (cur_lnum == 1 || !has_key(rendered.line_map, string(cur_lnum))) && first_file_lnum > 0
                target_lnum = first_file_lnum
            endif

            if cur_state.winid > 0 && win_id2win(cur_state.winid) > 0
                win_execute(cur_state.winid, 'normal! ' .. string(target_lnum) .. 'G0')
            endif

            if first_file_lnum > 0
                OpenDiff(target_lnum, view_id)
            else
                CloseDiff(key)
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
        diff_left_winid: -1,
        diff_right_winid: -1,
        diff_left_bufnr: -1,
        diff_right_bufnr: -1,
        diff_winid: -1,
        diff_bufnr: -1,
        current_diff_file: '',
        current_diff_section: '',
        cursor_timer: -1,
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

export def CloseDiff(key: string = '')
    var lookup_key = key != '' ? key : view.GetKey(view.GetCurrentId())
    if !has_key(views, lookup_key)
        return
    endif
    var state = views[lookup_key]
    var left_winid = get(state, 'diff_left_winid', -1)
    var right_winid = get(state, 'diff_right_winid', -1)

    diffoff!

    for wid in [left_winid, right_winid]
        if wid > 0 && win_id2win(wid) > 0
            win_execute(wid, 'diffoff')
            win_execute(wid, 'close!')
        endif
    endfor

    state.diff_left_winid = -1
    state.diff_right_winid = -1
    state.diff_left_bufnr = -1
    state.diff_right_bufnr = -1
    state.diff_winid = -1
    state.diff_bufnr = -1
    state.current_diff_file = ''
    state.current_diff_section = ''

    if state.winid > 0 && win_id2win(state.winid) > 0
        setwinvar(state.winid, '&winfixheight', 0)
        win_gotoid(state.winid)
    endif
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

    CloseDiff(key)

    patch.Open3Way(state.cwd, entry.file, state.winid, () => {
        Refresh()
    }, () => {
        Refresh()
    })
enddef

export def OpenDiff(target_lnum: number = -1, explicit_view_id: number = -1)
    var view_id: number = explicit_view_id > 0 ? explicit_view_id : view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var lnum = target_lnum > 0 ? target_lnum : line('.')
    var entry: dict<any> = get(state.line_map, string(lnum), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    patch.Close3Way()

    var status_height: number = get(g:, 'gitu_status_height', 15)

    var left_winid: number = get(state, 'diff_left_winid', -1)
    var right_winid: number = get(state, 'diff_right_winid', -1)
    var left_bufnr: number = get(state, 'diff_left_bufnr', -1)
    var right_bufnr: number = get(state, 'diff_right_bufnr', -1)

    var need_create = (left_winid <= 0 || win_id2win(left_winid) <= 0 || right_winid <= 0 || win_id2win(right_winid) <= 0)

    if need_create
        CloseDiff(key)

        botright new
        left_winid = win_getid()
        left_bufnr = buffer.InitCurrentScratch('gitu-diff', '[GitU:Diff-Left]')
        b:gitu_view_id = view_id
        nnoremap <buffer> <silent> q <ScriptCmd>status.CloseDiff()<CR>
        nnoremap <buffer> <silent> <expr> <C-j> v:count1 .. "\<C-e>"
        nnoremap <buffer> <silent> <expr> <C-k> v:count1 .. "\<C-y>"
        nnoremap <buffer> <silent> <Tab> <ScriptCmd>status.CycleFocus(1)<CR>
        nnoremap <buffer> <silent> <S-Tab> <ScriptCmd>status.CycleFocus(-1)<CR>

        rightbelow vnew
        right_winid = win_getid()
        right_bufnr = buffer.InitCurrentScratch('gitu-diff', '[GitU:Diff-Right]')
        b:gitu_view_id = view_id
        nnoremap <buffer> <silent> q <ScriptCmd>status.CloseDiff()<CR>
        nnoremap <buffer> <silent> <expr> <C-j> v:count1 .. "\<C-e>"
        nnoremap <buffer> <silent> <expr> <C-k> v:count1 .. "\<C-y>"
        nnoremap <buffer> <silent> <Tab> <ScriptCmd>status.CycleFocus(1)<CR>
        nnoremap <buffer> <silent> <S-Tab> <ScriptCmd>status.CycleFocus(-1)<CR>

        state.diff_left_winid = left_winid
        state.diff_right_winid = right_winid
        state.diff_left_bufnr = left_bufnr
        state.diff_right_bufnr = right_bufnr
        state.diff_winid = left_winid
        state.diff_bufnr = left_bufnr
    endif

    var left_lines: list<string> = []
    var right_lines: list<string> = []
    var left_name: string = ''
    var right_name: string = ''

    if entry.section == 'staged'
        left_lines = GetBlobLines(state.cwd, 'HEAD:' .. entry.file)
        right_lines = GetBlobLines(state.cwd, ':' .. entry.file)
        left_name = printf('[GitU:HEAD] %s', entry.file)
        right_name = printf('[GitU:STAGE] %s', entry.file)
    elseif entry.section == 'unstaged'
        left_lines = GetBlobLines(state.cwd, ':' .. entry.file)
        if left_lines == ['']
            left_lines = GetBlobLines(state.cwd, 'HEAD:' .. entry.file)
        endif
        var full_path = state.cwd .. '/' .. entry.file
        right_lines = filereadable(full_path) ? readfile(full_path) : ['']
        if empty(right_lines)
            right_lines = ['']
        endif
        left_name = printf('[GitU:STAGE] %s', entry.file)
        right_name = printf('[GitU:WORKTREE] %s', entry.file)
    else # untracked
        left_lines = ['']
        var full_path = state.cwd .. '/' .. entry.file
        right_lines = filereadable(full_path) ? readfile(full_path) : ['']
        if empty(right_lines)
            right_lines = ['']
        endif
        left_name = printf('[GitU:BASE] %s', entry.file)
        right_name = printf('[GitU:WORKTREE] %s', entry.file)
    endif

    win_execute(left_winid, 'diffoff')
    win_execute(right_winid, 'diffoff')

    setbufvar(left_bufnr, '&modifiable', 1)
    buffer.SetLines(left_bufnr, left_lines)
    setbufvar(left_bufnr, '&modifiable', 0)
    silent! execute printf('noautocmd call win_execute(%d, "file %s")', left_winid, fnameescape(left_name))

    setbufvar(right_bufnr, '&modifiable', 1)
    buffer.SetLines(right_bufnr, right_lines)
    setbufvar(right_bufnr, '&modifiable', 0)
    silent! execute printf('noautocmd call win_execute(%d, "file %s")', right_winid, fnameescape(right_name))

    win_execute(left_winid, 'filetype detect')
    win_execute(right_winid, 'filetype detect')

    win_execute(left_winid, 'diffthis')
    win_execute(right_winid, 'diffthis')
    win_execute(left_winid, 'diffupdate')

    state.current_diff_file = entry.file
    state.current_diff_section = entry.section

    if status_height > 0 && state.winid > 0 && win_id2win(state.winid) > 0
        setwinvar(state.winid, '&winfixheight', 1)
        win_execute(state.winid, 'resize ' .. string(status_height))
    endif

    if state.winid > 0 && win_id2win(state.winid) > 0
        win_gotoid(state.winid)
    endif
enddef

export def ToggleOrOpenDiff()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var left_winid = get(state, 'diff_left_winid', -1)
    if left_winid > 0 && win_id2win(left_winid) > 0
        CloseDiff(key)
    else
        OpenDiff()
    endif
enddef

export def MoveSubView(direction: number, count: number = 1)
    if patch.IsActive()
        patch.MoveView(direction, count)
        return
    endif

    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var left_winid: number = get(state, 'diff_left_winid', -1)
    var right_winid: number = get(state, 'diff_right_winid', -1)

    if left_winid > 0 && win_id2win(left_winid) > 0
        var scroll_char = direction > 0 ? "\<C-e>" : "\<C-y>"
        var feed_cmd = printf('call feedkeys("%d%s", "xt")', count, scroll_char)
        win_execute(left_winid, feed_cmd)
        win_execute(left_winid, 'syncbind')
        redraw
    endif
enddef

export def OnStatusCursorMoved()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var left_winid = get(state, 'diff_left_winid', -1)
    if left_winid <= 0 || win_id2win(left_winid) <= 0
        return
    endif

    var cur_l = line('.')
    var entry = get(state.line_map, string(cur_l), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    if entry.file == get(state, 'current_diff_file', '') && entry.section == get(state, 'current_diff_section', '')
        return
    endif

    if get(state, 'cursor_timer', -1) > 0
        timer_stop(state.cursor_timer)
        state.cursor_timer = -1
    endif

    state.cursor_timer = timer_start(50, (_) => {
        if !has_key(views, key)
            return
        endif
        var cur_s = views[key]
        cur_s.cursor_timer = -1
        OpenDiff(cur_l, view_id)
    })
enddef

export def CycleFocus(direction: number = 1)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var wins: list<number> = [state.winid]
    var left_winid = get(state, 'diff_left_winid', -1)
    if left_winid > 0 && win_id2win(left_winid) > 0
        add(wins, left_winid)
    endif
    var right_winid = get(state, 'diff_right_winid', -1)
    if right_winid > 0 && win_id2win(right_winid) > 0
        add(wins, right_winid)
    endif
    if len(wins) <= 1
        return
    endif

    var cur_winid = win_getid()
    var idx = index(wins, cur_winid)
    if idx < 0
        win_gotoid(wins[0])
        return
    endif

    var next_idx = (idx + direction + len(wins)) % len(wins)
    win_gotoid(wins[next_idx])
enddef

export def GetState(view_id: number = -1): dict<any>
    var id = view_id > 0 ? view_id : view.GetCurrentId()
    return get(views, view.GetKey(id), {})
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        var state = views[key]
        if get(state, 'cursor_timer', -1) > 0
            timer_stop(state.cursor_timer)
            state.cursor_timer = -1
        endif
        CloseDiff(key)
        patch.Close3Way()
        git.StopByKey('gitu_status_' .. key)
        git.StopByKey('gitu_status_action_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()
    buffer.CloseTabOrReset()
enddef

view.RegisterRefresher('status', RefreshAll)
