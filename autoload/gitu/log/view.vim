vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/log/parser.vim'
import autoload 'gitu/log/github.vim'
import autoload 'gitu/log/action.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

def LoadCommitDiff(view_id: number, hash: string, file_path: string)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key) || hash == ''
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'show',
        '--first-parent',
        '--format=',
        '--patch',
        hash,
    ]
    if file_path != ''
        add(args, '--')
        add(args, file_path)
    endif

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_diff_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            if res.status != 0
                buffer.SetLines(cur_state.diff_bufnr, empty(res.stderr) ? ['Failed to load diff.'] : res.stderr)
                return
            endif
            var lines: list<string> = empty(res.stdout) ? ['(No diff change)'] : res.stdout
            buffer.SetLines(cur_state.diff_bufnr, lines)
            buffer.ResetWindowTop(cur_state.diff_winid)
        },
    })
enddef

def LoadCommitDetail(view_id: number, hash: string)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key) || hash == ''
        return
    endif
    var state = views[key]

    var format_str: string = 'Commit: %H%d%nAuthor: %an <%ae>%nDate:   %ad%nParent: %p%n%n%B%n--- Files ---'
    var args: list<string> = [
        'show',
        '--first-parent',
        '--name-status',
        '--date=iso',
        '--format=' .. format_str,
        hash,
    ]

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_commit_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            if res.status != 0
                buffer.SetLines(cur_state.commit_bufnr, empty(res.stderr) ? ['Failed to load commit details.'] : res.stderr)
                return
            endif
            var formatted: list<string> = parser.FormatCommitDetail(res.stdout)
            buffer.SetLines(cur_state.commit_bufnr, formatted)
            buffer.ResetWindowTop(cur_state.commit_winid)
        },
    })
enddef

def FlushStreamLines(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if empty(state.stream_pending)
        return
    endif

    var lines = state.stream_pending
    state.stream_pending = []

    if !state.stream_started
        state.stream_started = true
        buffer.SetLines(state.log_bufnr, lines)
        state.line_count = len(lines)

        var first_commit_lnum = 1
        for idx in range(len(lines))
            var h = parser.ExtractCommitHash(lines[idx])
            if h != ''
                first_commit_lnum = idx + 1
                state.current_hash = h
                state.current_file = ''
                LoadCommitDetail(view_id, h)
                LoadCommitDiff(view_id, h, '')
                break
            endif
        endfor

        if state.log_winid > 0 && win_id2win(state.log_winid) > 0
            win_execute(state.log_winid, 'normal! ' .. string(first_commit_lnum) .. 'G0')
        endif
    else
        appendbufline(state.log_bufnr, state.line_count, lines)
        state.line_count += len(lines)

        if state.current_hash == ''
            var all_lines = getbufline(state.log_bufnr, 1, state.line_count)
            for idx in range(len(all_lines))
                var h = parser.ExtractCommitHash(all_lines[idx])
                if h != ''
                    state.current_hash = h
                    state.current_file = ''
                    LoadCommitDetail(view_id, h)
                    LoadCommitDiff(view_id, h, '')
                    if state.log_winid > 0 && win_id2win(state.log_winid) > 0
                        win_execute(state.log_winid, 'normal! ' .. string(idx + 1) .. 'G0')
                    endif
                    break
                endif
            endfor
        endif
    endif
enddef

def OnLogStdout(view_id: number, msgs: list<string>)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    for msg in msgs
        add(state.stream_pending, substitute(msg, '\s\+$', '', ''))
    endfor

    var threshold = state.stream_started ? 100 : 30
    if len(state.stream_pending) >= threshold
        FlushStreamLines(view_id)
    endif
enddef

def OnLogExit(view_id: number, res: dict<any>)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    if res.status != 0
        if !state.stream_started
            var err_lines: list<string> = empty(res.stderr) ? ['Failed to run git log.'] : res.stderr
            buffer.SetLines(state.log_bufnr, err_lines)
            buffer.SetLines(state.commit_bufnr, [])
            buffer.SetLines(state.diff_bufnr, [])
        endif
        return
    endif

    FlushStreamLines(view_id)

    if !state.stream_started || state.line_count == 0
        buffer.SetLines(state.log_bufnr, ['(No commits found)'])
        buffer.SetLines(state.commit_bufnr, [])
        buffer.SetLines(state.diff_bufnr, [])
    endif
enddef

def LoadLog(view_id: number)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    state.stream_started = false
    state.stream_pending = []
    state.line_count = 0

    var args: list<string> = [
        'log',
        '--graph',
        '--date=format:%Y-%m-%d %H:%M',
        '--pretty=format:%h%d %s <%an> (%ad)',
    ] + state.extra_args

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_log_' .. key,
        on_stdout: (msgs: list<string>) => OnLogStdout(view_id, msgs),
        on_exit: (res: dict<any>) => OnLogExit(view_id, res),
    })
enddef

export def Open(...extra_args: list<string>)
    var normalized_args = parser.NormalizeArgs(extra_args)
    var initial_cwd: string = git.ResolveInitialCwd()

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = view.GetKey(view_id)

    tabnew
    t:gitu_view_id = view_id

    var log_winid: number = win_getid()
    var log_bufnr: number = buffer.InitCurrentScratch('gitu-log', '[GitU:Log #' .. key .. ']')
    b:gitu_view_id = view_id

    rightbelow vnew
    var commit_winid: number = win_getid()
    var commit_bufnr: number = buffer.InitCurrentScratch('gitu-commit', '[GitU:Commit #' .. key .. ']')
    b:gitu_view_id = view_id

    rightbelow new
    var diff_winid: number = win_getid()
    var diff_bufnr: number = buffer.InitCurrentScratch('gitu-diff', '[GitU:Diff #' .. key .. ']')
    b:gitu_view_id = view_id

    var commit_height: number = get(g:, 'gitu_commit_height', 15)
    if commit_height > 0
        win_execute(commit_winid, 'resize ' .. string(commit_height))
    endif

    win_gotoid(log_winid)

    views[key] = {
        id: view_id,
        cwd: initial_cwd,
        extra_args: normalized_args,
        log_bufnr: log_bufnr,
        commit_bufnr: commit_bufnr,
        diff_bufnr: diff_bufnr,
        log_winid: log_winid,
        commit_winid: commit_winid,
        diff_winid: diff_winid,
        current_hash: '',
        current_file: '',
        stream_started: false,
        stream_pending: [],
        line_count: 0,
    }

    buffer.SetLines(log_bufnr, ['Loading git log...'])
    buffer.SetLines(commit_bufnr, ['Loading commit details...'])
    buffer.SetLines(diff_bufnr, ['Loading diff...'])

    git.ResolveRepoRoot(initial_cwd, (root: string, stderr: list<string>) => {
        if !has_key(views, key)
            return
        endif
        if root == ''
            var msg: list<string> = empty(stderr) ? ['Not a git repository.'] : stderr
            buffer.SetLines(views[key].log_bufnr, msg)
            buffer.SetLines(views[key].commit_bufnr, [])
            buffer.SetLines(views[key].diff_bufnr, [])
            return
        endif
        views[key].cwd = root
        LoadLog(view_id)
    })
enddef

export def OnLogCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var hash: string = parser.ExtractCommitHash(getline('.'))
    if hash == ''
        return
    endif
    if !force && hash == state.current_hash
        return
    endif

    state.current_hash = hash
    state.current_file = ''
    LoadCommitDetail(view_id, hash)
    LoadCommitDiff(view_id, hash, '')
enddef

export def OnCommitCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.current_hash == ''
        return
    endif

    var cur_lnum: number = line('.')
    var files_header_lnum: number = search('^--- Files ---$', 'bnW')
    var file_path: string = ''
    if files_header_lnum > 0 && cur_lnum > files_header_lnum
        file_path = parser.ExtractFilePath(getline(cur_lnum))
    endif

    if !force && file_path == state.current_file
        return
    endif

    state.current_file = file_path
    LoadCommitDiff(view_id, state.current_hash, file_path)
enddef

export def Refresh()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    views[key].current_hash = ''
    views[key].current_file = ''
    LoadLog(view_id)
enddef

export def RefreshAll()
    for view_id in keys(views)
        views[view_id].current_hash = ''
        views[view_id].current_file = ''
        LoadLog(str2nr(view_id))
    endfor
enddef

view.RegisterRefresher('log', RefreshAll)

export def CycleFocus(direction: number = 1)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var panes: list<number> = [state.log_winid, state.commit_winid, state.diff_winid]
    var cur_win: number = win_getid()
    var idx: number = index(panes, cur_win)
    if idx < 0
        idx = 0
    else
        idx = (idx + direction + len(panes)) % len(panes)
    endif
    var target_win: number = panes[idx]
    if win_id2win(target_win) > 0
        win_gotoid(target_win)
    endif
enddef

export def SelectCommitItem()
    OnCommitCursorMoved(true)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var diff_winid: number = views[key].diff_winid
    if win_id2win(diff_winid) > 0
        win_gotoid(diff_winid)
    endif
enddef

export def YankCommitHash(line_str: string = ''): string
    var target_line: string = (line_str != '') ? line_str : getline('.')
    var hash: string = parser.ExtractCommitHash(target_line)
    if hash == ''
        notify.Warn('No commit hash on current line')
        return ''
    endif

    var reg: string = v:register
    setreg(reg, hash)
    if reg == '"'
        if &clipboard =~# 'unnamedplus'
            setreg('+', hash)
        endif
        if &clipboard =~# 'unnamed'
            setreg('*', hash)
        endif
    endif

    notify.Info('Copied ' .. hash)
    return hash
enddef

def ResolveSelectedCommit(): dict<any>
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    var hash: string = parser.ExtractCommitHash(getline('.'))
    if hash == '' && has_key(views, key)
        hash = views[key].current_hash
    endif
    var cwd: string = has_key(views, key) ? views[key].cwd : getcwd()
    return { hash: hash, cwd: cwd, view_id: view_id }
enddef

export def OpenCommitWeb()
    var sel = ResolveSelectedCommit()
    if sel.hash == ''
        notify.Warn('No commit found for current line')
        return
    endif
    github.OpenCommit(sel.cwd, sel.hash)
enddef

export def OpenPullRequestWeb()
    var sel = ResolveSelectedCommit()
    if sel.hash == ''
        notify.Warn('No commit found for current line')
        return
    endif
    github.OpenPullRequest(sel.cwd, sel.hash)
enddef

export def PromptAction()
    var sel = ResolveSelectedCommit()
    if !has_key(views, view.GetKey(sel.view_id))
        return
    endif
    if sel.hash == ''
        notify.Warn('No commit selected for action')
        return
    endif
    action.Prompt(sel)
enddef

export def ExecuteAction(action_name: string)
    var sel = ResolveSelectedCommit()
    if !has_key(views, view.GetKey(sel.view_id))
        return
    endif
    if sel.hash == ''
        notify.Warn('No commit selected for action')
        return
    endif
    action.Execute(action_name, sel)
enddef

export def ActionComplete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return action.Complete(arg_lead, cmd_line, cursor_pos)
enddef

export def GetState(view_id: number = -1): dict<any>
    var id = view_id > 0 ? view_id : view.GetCurrentId()
    return get(views, view.GetKey(id), {})
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        git.StopByKey('gitu_log_' .. key)
        git.StopByKey('gitu_commit_' .. key)
        git.StopByKey('gitu_diff_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()
    buffer.CloseTabOrReset()
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return parser.Complete(arg_lead, cmd_line, cursor_pos)
enddef
