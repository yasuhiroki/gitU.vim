vim9script

import autoload 'gitu/buffer.vim'
import autoload 'gitu/git.vim'
import autoload 'gitu/stage.vim'

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

export def ParsePorcelain(lines: list<string>): dict<any>
    var result: dict<any> = {
        branch: '',
        staged: [],
        unstaged: [],
        untracked: [],
    }

    for line in lines
        if line =~ '^## '
            var branch_info: string = line[3 :]
            result.branch = branch_info
            continue
        endif

        if len(line) < 4
            continue
        endif

        var x: string = line[0]
        var y: string = line[1]
        var filepath: string = line[3 :]

        if x == '?' && y == '?'
            add(result.untracked, { status: '?', file: filepath })
            continue
        endif

        if x != ' ' && x != '?'
            var staged_file: string = filepath
            if (x == 'R' || x == 'C') && filepath =~ ' -> '
                var parts: list<string> = split(filepath, ' -> ')
                if len(parts) >= 2
                    staged_file = parts[1]
                endif
            endif
            add(result.staged, { status: x, file: staged_file, raw_file: filepath })
        endif

        if y != ' ' && y != '?'
            add(result.unstaged, { status: y, file: filepath })
        endif
    endfor

    return result
enddef

export def RenderStatus(parsed: dict<any>): dict<any>
    var lines: list<string> = []
    var line_map: dict<dict<any>> = {}

    if parsed.branch != ''
        add(lines, 'Branch: ' .. parsed.branch)
        add(lines, '')
    endif

    var has_changes: bool = false

    if len(parsed.staged) > 0
        has_changes = true
        add(lines, 'Changes to be committed:')
        for item in parsed.staged
            var disp_file: string = get(item, 'raw_file', item.file)
            var line_text: string = printf('  %s  %s', item.status, disp_file)
            add(lines, line_text)
            var lnum: number = len(lines)
            line_map[string(lnum)] = {
                section: 'staged',
                status: item.status,
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if len(parsed.unstaged) > 0
        has_changes = true
        add(lines, 'Changes not staged for commit:')
        for item in parsed.unstaged
            var line_text: string = printf('  %s  %s', item.status, item.file)
            add(lines, line_text)
            var lnum: number = len(lines)
            line_map[string(lnum)] = {
                section: 'unstaged',
                status: item.status,
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if len(parsed.untracked) > 0
        has_changes = true
        add(lines, 'Untracked files:')
        for item in parsed.untracked
            var line_text: string = printf('  ?  %s', item.file)
            add(lines, line_text)
            var lnum: number = len(lines)
            line_map[string(lnum)] = {
                section: 'untracked',
                status: '?',
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if !has_changes
        add(lines, 'nothing to commit, working tree clean')
    endif

    return { lines: lines, line_map: line_map }
enddef

export def BuildDiffArgs(section: string, file_path: string): list<string>
    if section == 'staged'
        return ['diff', '--cached', '--', file_path]
    elseif section == 'untracked'
        return ['diff', '--no-index', '--', '/dev/null', file_path]
    endif
    return ['diff', '--', file_path]
enddef

def LoadStatus(view_id: number)
    var key: string = GetViewKey(view_id)
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

            var parsed = ParsePorcelain(res.stdout)
            var rendered = RenderStatus(parsed)
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
    var buf_dir: string = expand('%:p:h')
    var initial_cwd: string = (buf_dir != '' && isdirectory(buf_dir)) ? buf_dir : getcwd()

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = GetViewKey(view_id)

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
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
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

export def GetSelectedFiles(state: dict<any>, start_lnum: number, end_lnum: number, action: string): list<string>
    if start_lnum <= 0 || end_lnum <= 0
        return []
    endif
    var s: number = min([start_lnum, end_lnum])
    var e: number = max([start_lnum, end_lnum])
    var files: list<string> = []
    for lnum in range(s, e)
        var entry: dict<any> = get(state.line_map, string(lnum), {})
        if empty(entry) || get(entry, 'file', '') == ''
            continue
        endif
        if action == 'stage' && entry.section != 'staged'
            if index(files, entry.file) < 0
                add(files, entry.file)
            endif
        elseif action == 'unstage' && entry.section == 'staged'
            if index(files, entry.file) < 0
                add(files, entry.file)
            endif
        endif
    endfor
    return files
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
                echohl ErrorMsg
                echomsg 'Failed to stage: ' .. join(res.stderr, ' ')
                echohl None
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
                echohl ErrorMsg
                echomsg 'Failed to unstage: ' .. join(res.stderr, ' ')
                echohl None
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

export def StageCurrent()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var cur_lnum: number = line('.')
    var files: list<string> = GetSelectedFiles(state, cur_lnum, cur_lnum, 'stage')
    StageFiles(key, state, files)
enddef

export def UnstageCurrent()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var cur_lnum: number = line('.')
    var files: list<string> = GetSelectedFiles(state, cur_lnum, cur_lnum, 'unstage')
    UnstageFiles(key, state, files)
enddef

export def StageVisual()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var start_lnum: number = line("'<")
    var end_lnum: number = line("'>")
    var files: list<string> = GetSelectedFiles(state, start_lnum, end_lnum, 'stage')
    StageFiles(key, state, files)
enddef

export def UnstageVisual()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var start_lnum: number = line("'<")
    var end_lnum: number = line("'>")
    var files: list<string> = GetSelectedFiles(state, start_lnum, end_lnum, 'unstage')
    UnstageFiles(key, state, files)
enddef

export def OpenPatchEdit()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var lnum: number = line('.')
    var entry: dict<any> = get(state.line_map, string(lnum), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    var diff_winid = get(state, 'diff_winid', -1)
    if diff_winid > 0 && win_id2win(diff_winid) > 0
        win_execute(diff_winid, 'close!')
    endif
    state.diff_winid = -1
    state.diff_bufnr = -1

    stage.Open3Way(state.cwd, entry.file, state.winid, () => {
        Refresh()
    })
enddef

export def OpenDiff()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var lnum: number = line('.')
    var entry: dict<any> = get(state.line_map, string(lnum), {})
    if empty(entry) || get(entry, 'file', '') == ''
        return
    endif

    stage.Close3Way()

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

    var args: list<string> = BuildDiffArgs(entry.section, entry.file)
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
            if cur_state.diff_winid > 0 && win_id2win(cur_state.diff_winid) > 0
                win_execute(cur_state.diff_winid, 'normal! gg0')
            endif
            if status_height > 0 && cur_state.winid > 0 && win_id2win(cur_state.winid) > 0
                setwinvar(cur_state.winid, '&winfixheight', 1)
                win_execute(cur_state.winid, 'resize ' .. string(status_height))
            endif
        },
    })
enddef

export def OnBufWipeout()
    var view_id: number = GetCurrentViewId()
    var key: string = GetViewKey(view_id)
    if has_key(views, key)
        var state = views[key]
        var diff_winid = get(state, 'diff_winid', -1)
        if diff_winid > 0 && win_id2win(diff_winid) > 0
            win_execute(diff_winid, 'close!')
        endif
        stage.Close3Way()
        git.StopByKey('gitu_status_' .. key)
        git.StopByKey('gitu_status_action_' .. key)
        git.StopByKey('gitu_status_diff_' .. key)
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
