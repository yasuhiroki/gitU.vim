vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/blame/parser.vim'
import autoload 'gitu/log/github.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

def SetWindowsBind(blame_winid: number, file_winid: number, enabled: bool)
    var val: number = enabled ? 1 : 0
    if blame_winid > 0 && win_id2win(blame_winid) > 0
        setwinvar(blame_winid, '&scrollbind', val)
        setwinvar(blame_winid, '&cursorbind', val)
    endif
    if file_winid > 0 && win_id2win(file_winid) > 0
        setwinvar(file_winid, '&scrollbind', val)
        setwinvar(file_winid, '&cursorbind', val)
    endif
enddef

def SyncWindowPositions(blame_winid: number, file_winid: number, lnum: number)
    SetWindowsBind(blame_winid, file_winid, false)

    if blame_winid > 0 && win_id2win(blame_winid) > 0
        win_execute(blame_winid, printf('normal! %dG0zz', lnum))
    endif
    if file_winid > 0 && win_id2win(file_winid) > 0
        win_execute(file_winid, printf('normal! %dG0zz', lnum))
    endif

    SetWindowsBind(blame_winid, file_winid, true)
    if blame_winid > 0 && win_id2win(blame_winid) > 0
        win_execute(blame_winid, 'syncbind')
    endif
enddef

def CurrentHistoryItem(state: dict<any>): dict<any>
    if empty(state.history) || state.history_idx < 0 || state.history_idx >= len(state.history)
        return {}
    endif
    return state.history[state.history_idx]
enddef

def UpdateFileBufferName(state: dict<any>, hist_item: dict<any>)
    var rev_label: string = hist_item.rev == '' ? 'WORKTREE' : hist_item.rev[0 : 6]
    var buf_title = printf('[GitU:BlameFile #%d] %s (%s)', state.id, hist_item.rel_file, rev_label)
    if bufexists(state.file_bufnr)
        win_execute(state.file_winid, 'silent! file ' .. fnameescape(buf_title))
    endif
enddef

def OnBlameLoaded(view_id: number, res: dict<any>)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var cur_state = views[key]

    if res.status != 0
        SetWindowsBind(cur_state.blame_winid, cur_state.file_winid, false)
        var err_lines: list<string> = empty(res.stderr) ? ['Failed to run git blame.'] : res.stderr
        buffer.SetLines(cur_state.blame_bufnr, err_lines)
        buffer.SetLines(cur_state.file_bufnr, [])
        cur_state.entries = []
        cur_state.loaded = true
        return
    endif

    var parsed = parser.ParseLinePorcelain(res.stdout)
    cur_state.entries = parsed.entries

    if empty(parsed.blame_lines)
        SetWindowsBind(cur_state.blame_winid, cur_state.file_winid, false)
        buffer.SetLines(cur_state.blame_bufnr, ['(Empty file)'])
        buffer.SetLines(cur_state.file_bufnr, [''])
        cur_state.loaded = true
        return
    endif

    var hist_item = CurrentHistoryItem(cur_state)
    UpdateFileBufferName(cur_state, hist_item)

    SetWindowsBind(cur_state.blame_winid, cur_state.file_winid, false)
    buffer.SetLines(cur_state.blame_bufnr, parsed.blame_lines)
    buffer.SetLines(cur_state.file_bufnr, parsed.file_lines)

    var target_lnum: number = get(hist_item, 'lnum', 1)
    var max_lnum: number = len(parsed.blame_lines)
    if target_lnum < 1
        target_lnum = 1
    elseif target_lnum > max_lnum
        target_lnum = max_lnum
    endif

    SyncWindowPositions(cur_state.blame_winid, cur_state.file_winid, target_lnum)
    cur_state.loaded = true
enddef

def LoadBlame(view_id: number)
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var hist_item = CurrentHistoryItem(state)
    if empty(hist_item)
        return
    endif

    state.loaded = false
    var args: list<string> = ['blame', '--line-porcelain']
    if hist_item.rev != ''
        add(args, hist_item.rev)
    endif
    extend(args, ['--', hist_item.rel_file])

    git.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_blame_' .. key,
        on_exit: (res: dict<any>) => OnBlameLoaded(view_id, res),
    })
enddef

def OnRepoResolved(
    view_id: number,
    key: string,
    file_path: string,
    initial_rev: string,
    initial_lnum: number,
    root: string,
    stderr: list<string>
)
    if !has_key(views, key)
        return
    endif
    if root == ''
        var msg: list<string> = empty(stderr) ? ['Not a git repository.'] : stderr
        buffer.SetLines(views[key].blame_bufnr, msg)
        buffer.SetLines(views[key].file_bufnr, [])
        views[key].loaded = true
        return
    endif

    var rel_file = parser.ToRepoRelativePath(root, file_path)
    views[key].cwd = root
    views[key].history = [{
        rev: initial_rev,
        rel_file: rel_file,
        lnum: initial_lnum,
    }]
    views[key].history_idx = 0
    LoadBlame(view_id)
enddef
def SetupFilePaneMappings()
    nnoremap <buffer> <silent> q <ScriptCmd>Close()<CR>
    nnoremap <buffer> <silent> u <ScriptCmd>Refresh()<CR>
    nnoremap <buffer> <silent> <CR> <ScriptCmd>BlameParent()<CR>
    nnoremap <buffer> <silent> <C-o> <ScriptCmd>HistoryBack()<CR>
    nnoremap <buffer> <silent> <C-i> <ScriptCmd>HistoryForward()<CR>
enddef

export def Open(initial_rev: string = '')
    var file_path: string = expand('%:p')
    if file_path == '' || !filereadable(file_path)
        notify.Warn('No readable file in current buffer')
        return
    endif

    var initial_lnum: number = line('.')
    var orig_filetype: string = &filetype
    var initial_cwd: string = fnamemodify(file_path, ':h')

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = view.GetKey(view_id)

    tabnew
    t:gitu_view_id = view_id

    var blame_winid: number = win_getid()
    var blame_bufnr: number = buffer.InitCurrentScratch('gitu-blame', '[GitU:Blame #' .. key .. ']')
    b:gitu_view_id = view_id

    rightbelow vnew
    var file_winid: number = win_getid()
    var file_bufnr: number = buffer.InitCurrentScratch(orig_filetype, '[GitU:BlameFile #' .. key .. ']')
    b:gitu_view_id = view_id
    setlocal number
    setlocal norelativenumber
    setlocal nowrap
    setlocal cursorline
    SetupFilePaneMappings()

    var blame_width: number = get(g:, 'gitu_blame_width', 55)
    if blame_width > 0
        setwinvar(blame_winid, '&winfixwidth', 1)
        win_execute(blame_winid, 'vertical resize ' .. string(blame_width))
    endif

    win_gotoid(blame_winid)

    views[key] = {
        id: view_id,
        cwd: initial_cwd,
        file_path: file_path,
        blame_bufnr: blame_bufnr,
        file_bufnr: file_bufnr,
        blame_winid: blame_winid,
        file_winid: file_winid,
        entries: [],
        history: [],
        history_idx: -1,
        loaded: false,
    }

    buffer.SetLines(blame_bufnr, ['Loading git blame...'])
    buffer.SetLines(file_bufnr, ['Loading file...'])

    git.ResolveRepoRoot(initial_cwd, (root: string, stderr: list<string>) => {
        OnRepoResolved(view_id, key, file_path, initial_rev, initial_lnum, root, stderr)
    })
enddef

def GetCurrentLineEntry(state: dict<any>): dict<any>
    var lnum: number = line('.')
    if lnum < 1 || lnum > len(state.entries)
        return {}
    endif
    return state.entries[lnum - 1]
enddef

export def BlameParent()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var entry = GetCurrentLineEntry(state)
    if empty(entry)
        return
    endif

    var prev_hash: string = get(entry, 'prev_hash', '')
    if prev_hash == ''
        notify.Warn('No older commit for this line (initial commit)')
        return
    endif

    var cur_hist = CurrentHistoryItem(state)
    if !empty(cur_hist)
        cur_hist.lnum = line('.')
    endif

    if state.history_idx < len(state.history) - 1
        state.history = state.history[0 : state.history_idx]
    endif

    var prev_file: string = get(entry, 'prev_file', '')
    if prev_file == '' && !empty(cur_hist)
        prev_file = cur_hist.rel_file
    endif
    var target_lnum: number = get(entry, 'orig_lnum', line('.'))

    add(state.history, {
        rev: prev_hash,
        rel_file: prev_file,
        lnum: target_lnum,
    })
    state.history_idx = len(state.history) - 1

    notify.Info(printf('Blaming parent %s (%s)...', prev_hash[0 : 6], prev_file))
    LoadBlame(view_id)
enddef

export def HistoryBack()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.history_idx <= 0
        notify.Info('Already at oldest blame history entry')
        return
    endif

    var cur_hist = CurrentHistoryItem(state)
    if !empty(cur_hist)
        cur_hist.lnum = line('.')
    endif

    state.history_idx -= 1
    LoadBlame(view_id)
enddef

export def HistoryForward()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.history_idx >= len(state.history) - 1
        notify.Info('Already at newest blame history entry')
        return
    endif

    var cur_hist = CurrentHistoryItem(state)
    if !empty(cur_hist)
        cur_hist.lnum = line('.')
    endif

    state.history_idx += 1
    LoadBlame(view_id)
enddef

export def YankCommitHash(): string
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return ''
    endif
    var entry = GetCurrentLineEntry(views[key])
    var hash: string = get(entry, 'short_hash', '')
    if hash == '' || hash =~ '^0\+$'
        notify.Warn('No committed hash on current line')
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

export def OpenCommitWeb()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var entry = GetCurrentLineEntry(state)
    var hash: string = get(entry, 'hash', '')
    if hash == '' || hash =~ '^0\+$'
        notify.Warn('No committed hash on current line')
        return
    endif
    github.OpenCommit(state.cwd, hash)
enddef

export def OpenPullRequestWeb()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var entry = GetCurrentLineEntry(state)
    var hash: string = get(entry, 'hash', '')
    if hash == '' || hash =~ '^0\+$'
        notify.Warn('No committed hash on current line')
        return
    endif
    github.OpenPullRequest(state.cwd, hash)
enddef

export def Refresh()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var cur_hist = CurrentHistoryItem(views[key])
    if !empty(cur_hist)
        cur_hist.lnum = line('.')
    endif
    LoadBlame(view_id)
enddef

export def GetState(view_id: number = -1): dict<any>
    var id = view_id > 0 ? view_id : view.GetCurrentId()
    return get(views, view.GetKey(id), {})
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        git.StopByKey('gitu_blame_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()
    buffer.CloseTabOrReset()
enddef
