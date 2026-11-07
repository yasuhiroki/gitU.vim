vim9script

import autoload 'gitu/buffer.vim'
import autoload 'gitu/git.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

def GetViewKey(view_id: number): string
    return string(view_id)
enddef

def GetCurrentViewId(): number
    if exists('b:gitu_view_id')
        return b:gitu_view_id
    endif
    if exists('t:gitu_view_id')
        return t:gitu_view_id
    endif
    return -1
enddef

export def ExtractCommitHash(line: string): string
    return matchstr(line, '^[*|/\\_. -]*\*[ |/\\_. -]*\zs\x\{7,40\}\ze\>')
enddef

export def ExtractFilePath(line: string): string
    var renamed: string = matchstr(line, '^[RC]\d*\t[^\t]\+\t\zs.\+$')
    if renamed != ''
        return renamed
    endif
    return matchstr(line, '^[MADTU]\t\zs.\+$')
enddef

def ResetWindowTop(winid: number)
    if winid > 0 && win_id2win(winid) > 0
        win_execute(winid, 'normal! gg0')
    endif
enddef

def LoadCommitDiff(view_id: number, hash: string, file_path: string)
    var key: string = GetViewKey(view_id)
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
            ResetWindowTop(cur_state.diff_winid)
        },
    })
enddef

def LoadCommitDetail(view_id: number, hash: string)
    var key: string = GetViewKey(view_id)
    if !has_key(views, key) || hash == ''
        return
    endif
    var state = views[key]

    var format_str: string = 'Commit: %H%d%nAuthor: %an <%ae>%nDate:   %ad%nParent: %p%n%n%w(0,4,4)%B%n%w(0,0,0)--- Files ---'
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
            buffer.SetLines(cur_state.commit_bufnr, res.stdout)
            ResetWindowTop(cur_state.commit_winid)
        },
    })
enddef

def LoadLog(view_id: number)
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'log',
        '--graph',
        '--date=format:%Y-%m-%d %H:%M',
        '--pretty=format:%h%d %s <%an> (%ad)',
    ] + state.extra_args

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_log_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur_state = views[key]
            if res.status != 0
                var err_lines: list<string> = empty(res.stderr) ? ['Failed to run git log.'] : res.stderr
                buffer.SetLines(cur_state.log_bufnr, err_lines)
                buffer.SetLines(cur_state.commit_bufnr, [])
                buffer.SetLines(cur_state.diff_bufnr, [])
                return
            endif

            if empty(res.stdout)
                buffer.SetLines(cur_state.log_bufnr, ['(No commits found)'])
                buffer.SetLines(cur_state.commit_bufnr, [])
                buffer.SetLines(cur_state.diff_bufnr, [])
                return
            endif

            buffer.SetLines(cur_state.log_bufnr, res.stdout)

            var first_commit_lnum: number = 1
            for idx in range(len(res.stdout))
                if ExtractCommitHash(res.stdout[idx]) != ''
                    first_commit_lnum = idx + 1
                    break
                endif
            endfor

            if cur_state.log_winid > 0 && win_id2win(cur_state.log_winid) > 0
                win_execute(cur_state.log_winid, 'normal! ' .. string(first_commit_lnum) .. 'G0')
            endif

            var first_hash: string = ExtractCommitHash(res.stdout[first_commit_lnum - 1])
            if first_hash != ''
                cur_state.current_hash = first_hash
                cur_state.current_file = ''
                LoadCommitDetail(view_id, first_hash)
                LoadCommitDiff(view_id, first_hash, '')
            endif
        },
    })
enddef

export def Open(...extra_args: list<string>)
    var buf_dir: string = expand('%:p:h')
    var initial_cwd: string = (buf_dir != '' && isdirectory(buf_dir)) ? buf_dir : getcwd()

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = GetViewKey(view_id)

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

    win_gotoid(log_winid)

    views[key] = {
        id: view_id,
        cwd: initial_cwd,
        extra_args: extra_args,
        log_bufnr: log_bufnr,
        commit_bufnr: commit_bufnr,
        diff_bufnr: diff_bufnr,
        log_winid: log_winid,
        commit_winid: commit_winid,
        diff_winid: diff_winid,
        current_hash: '',
        current_file: '',
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
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var hash: string = ExtractCommitHash(getline('.'))
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
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
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
        file_path = ExtractFilePath(getline(cur_lnum))
    endif

    if !force && file_path == state.current_file
        return
    endif

    state.current_file = file_path
    LoadCommitDiff(view_id, state.current_hash, file_path)
enddef

export def Refresh()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    views[key].current_hash = ''
    views[key].current_file = ''
    LoadLog(view_id)
enddef

export def CycleFocus(direction: number = 1)
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
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
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var diff_winid: number = views[key].diff_winid
    if win_id2win(diff_winid) > 0
        win_gotoid(diff_winid)
    endif
enddef

export def OnBufWipeout()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if has_key(views, key)
        git.StopByKey('gitu_log_' .. key)
        git.StopByKey('gitu_commit_' .. key)
        git.StopByKey('gitu_diff_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()

    if tabpagenr('$') > 1
        tabclose
    else
        silent! only
        enew
    endif
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var candidates: list<string> = [
        '--all',
        '--branches',
        '--tags',
        '--remotes',
        '--first-parent',
        '--merges',
        '--no-merges',
        '-n',
    ]
    if arg_lead == ''
        return candidates
    endif
    return filter(candidates, (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
