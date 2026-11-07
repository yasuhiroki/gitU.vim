vim9script

import autoload 'gitu/buffer.vim'
import autoload 'gitu/git.vim'
import autoload 'gitu/github.vim'

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

export def StripTrailingWhitespace(lines: list<string>): list<string>
    return mapnew(lines, (_, line: string): string => substitute(line, '\s\+$', '', ''))
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

export def FormatCommitDetail(lines: list<string>): list<string>
    var out_lines = copy(lines)
    var files_idx: number = index(out_lines, '--- Files ---')
    if files_idx < 0
        return out_lines
    endif

    while files_idx > 0 && out_lines[files_idx - 1] =~ '^\s*$'
        remove(out_lines, files_idx - 1)
        files_idx -= 1
    endwhile

    insert(out_lines, '', files_idx)
    return out_lines
enddef

def LoadCommitDetail(view_id: number, hash: string)
    var key: string = GetViewKey(view_id)
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
            var formatted: list<string> = FormatCommitDetail(res.stdout)
            buffer.SetLines(cur_state.commit_bufnr, formatted)
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

            var log_lines: list<string> = StripTrailingWhitespace(res.stdout)
            buffer.SetLines(cur_state.log_bufnr, log_lines)

            var first_commit_lnum: number = 1
            for idx in range(len(log_lines))
                if ExtractCommitHash(log_lines[idx]) != ''
                    first_commit_lnum = idx + 1
                    break
                endif
            endfor

            if cur_state.log_winid > 0 && win_id2win(cur_state.log_winid) > 0
                win_execute(cur_state.log_winid, 'normal! ' .. string(first_commit_lnum) .. 'G0')
            endif

            var first_hash: string = ExtractCommitHash(log_lines[first_commit_lnum - 1])
            if first_hash != ''
                cur_state.current_hash = first_hash
                cur_state.current_file = ''
                LoadCommitDetail(view_id, first_hash)
                LoadCommitDiff(view_id, first_hash, '')
            endif
        },
    })
enddef

export def NormalizeArgs(raw_args: list<string>): list<string>
    var result: list<string> = []
    var patterns: list<string> = []
    var skip_next = false

    for i in range(len(raw_args))
        if skip_next
            skip_next = false
            continue
        endif

        var arg = raw_args[i]
        if arg == '-n' || arg == '-L' || arg == '-S' || arg == '-G'
            add(result, arg)
            if i + 1 < len(raw_args)
                add(result, raw_args[i + 1])
                skip_next = true
            endif
        elseif arg =~ '^--%(since|after|until|before|max-count|skip|grep|author|committer)='
            add(result, arg)
        elseif arg == '--since' || arg == '--after' || arg == '--until' || arg == '--before' || arg == '--max-count' || arg == '--skip' || arg == '--grep' || arg == '--author' || arg == '--committer'
            add(result, arg)
            if i + 1 < len(raw_args)
                add(result, raw_args[i + 1])
                skip_next = true
            endif
        elseif arg =~ '^-'
            add(result, arg)
        else
            add(patterns, arg)
        endif
    endfor

    var has_diff_filter = false
    for item in result
        if item == '-G' || item =~ '^-G' || item == '-S' || item =~ '^-S'
            has_diff_filter = true
            break
        endif
    endfor

    if !has_diff_filter && !empty(patterns)
        var combined_pattern = join(patterns, ' ')
        add(result, '-G' .. combined_pattern)
    endif

    return result
enddef

export def Open(...extra_args: list<string>)
    var normalized_args = NormalizeArgs(extra_args)
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

export def YankCommitHash(line_str: string = ''): string
    var target_line: string = (line_str != '') ? line_str : getline('.')
    var hash: string = ExtractCommitHash(target_line)
    if hash == ''
        echohl WarningMsg
        echomsg 'No commit hash on current line'
        echohl None
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

    echomsg 'Copied ' .. hash
    return hash
enddef

export def OpenCommitWeb()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    var hash: string = ExtractCommitHash(getline('.'))
    if hash == '' && has_key(views, key)
        hash = views[key].current_hash
    endif
    if hash == ''
        echohl WarningMsg
        echomsg 'No commit found for current line'
        echohl None
        return
    endif
    var cwd: string = has_key(views, key) ? views[key].cwd : getcwd()
    github.OpenCommit(cwd, hash)
enddef

export def OpenPullRequestWeb()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    var hash: string = ExtractCommitHash(getline('.'))
    if hash == '' && has_key(views, key)
        hash = views[key].current_hash
    endif
    if hash == ''
        echohl WarningMsg
        echomsg 'No commit found for current line'
        echohl None
        return
    endif
    var cwd: string = has_key(views, key) ? views[key].cwd : getcwd()
    github.OpenPullRequest(cwd, hash)
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
        '-G',
        '-S',
    ]
    if arg_lead == ''
        return candidates
    endif
    return filter(candidates, (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
