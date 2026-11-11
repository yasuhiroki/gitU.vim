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

def LoadSpecialDiff(view_id: number, special: dict<any>, file_path: string)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var args: list<string> = []
    if special.type == 'unstaged'
        args = ['diff']
        if file_path != ''
            extend(args, ['--', file_path])
        endif
    elseif special.type == 'staged'
        args = ['diff', '--cached']
        if file_path != ''
            extend(args, ['--', file_path])
        endif
    elseif special.type == 'stash'
        var stash_ref = get(special, 'ref', '')
        args = ['diff', stash_ref .. '^1', stash_ref]
        if file_path != ''
            extend(args, ['--', file_path])
        endif
    else
        return
    endif

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_diff_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            if res.status != 0 && res.status != 1
                buffer.SetLines(cur_state.diff_bufnr, empty(res.stderr) ? ['Failed to load diff.'] : res.stderr)
                return
            endif
            var lines: list<string> = empty(res.stdout) ? ['(No diff change)'] : res.stdout
            buffer.SetLines(cur_state.diff_bufnr, lines)
            buffer.ResetWindowTop(cur_state.diff_winid)
        },
    })
enddef

def LoadSpecialDetail(view_id: number, special: dict<any>)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    if special.type == 'unstaged'
        git.Run(['diff', '--name-status'], {
            cwd: state.cwd,
            task_key: 'gitu_commit_' .. key,
            on_exit: (res: dict<any>) => {
                if !has_key(views, key)
                    return
                endif
                var cur_state = views[key]
                var header = [
                    'Unstaged changes',
                    'Changes in working tree not yet staged for commit.',
                    '',
                    '--- Files ---',
                ]
                var files = res.status == 0 ? res.stdout : []
                var lines = header + files
                buffer.SetLines(cur_state.commit_bufnr, lines)
                buffer.ResetWindowTop(cur_state.commit_winid)
            },
        })
    elseif special.type == 'staged'
        git.Run(['diff', '--cached', '--name-status'], {
            cwd: state.cwd,
            task_key: 'gitu_commit_' .. key,
            on_exit: (res: dict<any>) => {
                if !has_key(views, key)
                    return
                endif
                var cur_state = views[key]
                var header = [
                    'Staged changes',
                    'Changes to be committed (git index).',
                    '',
                    '--- Files ---',
                ]
                var files = res.status == 0 ? res.stdout : []
                var lines = header + files
                buffer.SetLines(cur_state.commit_bufnr, lines)
                buffer.ResetWindowTop(cur_state.commit_winid)
            },
        })
    elseif special.type == 'stash'
        var stash_ref = get(special, 'ref', '')
        var format_str: string = 'Stash: ' .. stash_ref .. '%nCommit: %H%d%nAuthor: %an <%ae>%nDate:   %ad%n%n%B%n--- Files ---'
        var args: list<string> = [
            'show',
            '--first-parent',
            '--name-status',
            '--date=iso',
            '--format=' .. format_str,
            stash_ref,
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
                    buffer.SetLines(cur_state.commit_bufnr, empty(res.stderr) ? ['Failed to load stash details.'] : res.stderr)
                    return
                endif
                var formatted: list<string> = parser.FormatCommitDetail(res.stdout)
                buffer.SetLines(cur_state.commit_bufnr, formatted)
                buffer.ResetWindowTop(cur_state.commit_winid)
            },
        })
    endif
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

def SelectItemAtLnum(view_id: number, lnum: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var lines = getbufline(state.log_bufnr, lnum)
    if empty(lines)
        return
    endif
    var cur_line = lines[0]

    var special = parser.ExtractSpecialRef(cur_line)
    if !empty(special)
        var item_id = special.type == 'stash' ? special.ref : special.type
        state.current_item = item_id
        state.current_special = special
        state.current_hash = get(special, 'hash', '')
        state.current_file = ''
        LoadSpecialDetail(view_id, special)
        LoadSpecialDiff(view_id, special, '')
        return
    endif

    var hash = parser.ExtractCommitHash(cur_line)
    if hash != ''
        state.current_item = hash
        state.current_special = {}
        state.current_hash = hash
        state.current_file = ''
        LoadCommitDetail(view_id, hash)
        LoadCommitDiff(view_id, hash, '')
        return
    endif
enddef

def RenderLog(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    if !state.status_done || !state.stash_done || !state.log_done
        return
    endif

    var preludes = parser.ParseStatusPrelude(state.status_lines)
    extend(preludes, parser.ParseStashPrelude(state.stash_lines))

    var all_lines = preludes + state.log_lines
    if empty(all_lines)
        buffer.SetLines(state.log_bufnr, ['(No commits found)'])
        buffer.SetLines(state.commit_bufnr, [])
        buffer.SetLines(state.diff_bufnr, [])
        return
    endif

    buffer.SetLines(state.log_bufnr, all_lines)

    var target_lnum = 1
    if state.current_item != ''
        for idx in range(len(all_lines))
            var cur_l = all_lines[idx]
            var special = parser.ExtractSpecialRef(cur_l)
            if !empty(special)
                var item_id = special.type == 'stash' ? special.ref : special.type
                if item_id == state.current_item
                    target_lnum = idx + 1
                    break
                endif
            else
                var h = parser.ExtractCommitHash(cur_l)
                if h != '' && h == state.current_item
                    target_lnum = idx + 1
                    break
                endif
            endif
        endfor
    elseif state.prev_lnum > 0
        target_lnum = min([state.prev_lnum, len(all_lines)])
    endif

    if state.log_winid > 0 && win_id2win(state.log_winid) > 0
        win_execute(state.log_winid, 'normal! ' .. string(target_lnum) .. 'G0')
    endif

    SelectItemAtLnum(view_id, target_lnum)
enddef

def LoadLog(view_id: number)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    state.status_done = false
    state.stash_done = false
    state.log_done = false
    state.status_lines = []
    state.stash_lines = []
    state.log_lines = []

    git.Run(['status', '--porcelain=v1'], {
        cwd: state.cwd,
        task_key: 'gitu_log_status_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            views[key].status_done = true
            views[key].status_lines = (res.status == 0) ? res.stdout : []
            RenderLog(view_id)
        },
    })

    git.Run(['stash', 'list', '--pretty=format:%h %s (%cd)', '--date=format:%Y-%m-%d %H:%M'], {
        cwd: state.cwd,
        task_key: 'gitu_log_stash_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            views[key].stash_done = true
            views[key].stash_lines = (res.status == 0) ? res.stdout : []
            RenderLog(view_id)
        },
    })

    var log_args: list<string> = [
        'log',
        '--graph',
        '--date=format:%Y-%m-%d %H:%M',
        '--pretty=format:%h%d %s <%an> (%ad)',
    ]
    var has_max_count = false
    for extra in state.extra_args
        if extra =~# '^-\d\+$' || extra =~# '^-n' || extra =~# '^--max-count'
            has_max_count = true
            break
        endif
    endfor
    if !has_max_count
        var max_count = get(g:, 'gitu_log_max_count', 1000)
        if max_count > 0
            add(log_args, '--max-count=' .. string(max_count))
        endif
    endif
    log_args += state.extra_args

    git.Run(log_args, {
        cwd: state.cwd,
        task_key: 'gitu_log_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            views[key].log_done = true
            if res.status != 0
                views[key].log_lines = []
            else
                views[key].log_lines = res.stdout
            endif
            RenderLog(view_id)
        },
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
        current_item: '',
        current_special: {},
        current_hash: '',
        current_file: '',
        prev_lnum: 1,
        cursor_timer: -1,
        status_done: false,
        stash_done: false,
        log_done: false,
        status_lines: [],
        stash_lines: [],
        log_lines: [],
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

def DoLogCursorMoved(view_id: number, force: bool)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var cur_line = getline('.')

    var special = parser.ExtractSpecialRef(cur_line)
    if !empty(special)
        var item_id = special.type == 'stash' ? special.ref : special.type
        if !force && item_id == state.current_item
            return
        endif
        state.current_item = item_id
        state.current_special = special
        state.current_hash = get(special, 'hash', '')
        state.current_file = ''
        LoadSpecialDetail(view_id, special)
        LoadSpecialDiff(view_id, special, '')
        return
    endif

    var hash: string = parser.ExtractCommitHash(cur_line)
    if hash == ''
        return
    endif
    if !force && hash == state.current_item
        return
    endif

    state.current_item = hash
    state.current_special = {}
    state.current_hash = hash
    state.current_file = ''
    LoadCommitDetail(view_id, hash)
    LoadCommitDiff(view_id, hash, '')
enddef

export def OnLogCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.cursor_timer > 0
        timer_stop(state.cursor_timer)
        state.cursor_timer = -1
    endif

    if force
        DoLogCursorMoved(view_id, true)
    else
        state.cursor_timer = timer_start(50, (_) => {
            if has_key(views, key)
                views[key].cursor_timer = -1
                DoLogCursorMoved(view_id, false)
            endif
        })
    endif
enddef

export def OnCommitCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.current_hash == '' && empty(state.current_special)
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
    if !empty(state.current_special)
        LoadSpecialDiff(view_id, state.current_special, file_path)
    else
        LoadCommitDiff(view_id, state.current_hash, file_path)
    endif
enddef

export def Refresh()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.log_winid > 0 && win_id2win(state.log_winid) > 0
        state.prev_lnum = line('.', state.log_winid)
    endif
    LoadLog(view_id)
enddef

export def RefreshAll()
    for view_id in keys(views)
        var state = views[view_id]
        if state.log_winid > 0 && win_id2win(state.log_winid) > 0
            state.prev_lnum = line('.', state.log_winid)
        endif
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
        var special = parser.ExtractSpecialRef(target_line)
        if !empty(special) && special.type == 'stash' && get(special, 'hash', '') != ''
            hash = special.hash
        endif
    endif

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
    var cur_line = getline('.')
    var hash: string = parser.ExtractCommitHash(cur_line)
    if hash == '' && &filetype !=# 'gitu-log' && has_key(views, key) && empty(views[key].current_special)
        hash = views[key].current_hash
    endif
    var cwd: string = has_key(views, key) ? views[key].cwd : getcwd()
    return { hash: hash, cwd: cwd, view_id: view_id }
enddef

export def RebaseInteractive()
    var sel = ResolveSelectedCommit()
    if !has_key(views, view.GetKey(sel.view_id))
        return
    endif
    if sel.hash == ''
        notify.Warn('No commit selected for interactive rebase')
        return
    endif
    action.Execute('rebase', sel)
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

export def MoveDiffView(direction: number, count: number = 1)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var diff_winid: number = get(state, 'diff_winid', -1)
    if diff_winid > 0 && win_id2win(diff_winid) > 0
        var cmd = direction > 0 ? 'j' : 'k'
        win_execute(diff_winid, 'normal! ' .. string(count) .. cmd)
        redraw
    endif
enddef

export def GetState(view_id: number = -1): dict<any>
    var id = view_id > 0 ? view_id : view.GetCurrentId()
    return get(views, view.GetKey(id), {})
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        if views[key].cursor_timer > 0
            timer_stop(views[key].cursor_timer)
            views[key].cursor_timer = -1
        endif
        git.StopByKey('gitu_log_' .. key)
        git.StopByKey('gitu_log_status_' .. key)
        git.StopByKey('gitu_log_stash_' .. key)
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
