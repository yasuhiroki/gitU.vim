vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/notify.vim'

var current_session: dict<any> = {}

def GetIndexMode(repo_root: string, rel_file_path: string): string
    var out: string = system('git -C ' .. fnameescape(repo_root) .. ' ls-files --stage -- ' .. fnameescape(rel_file_path))
    if v:shell_error == 0 && out != ''
        var tokens: list<string> = split(out)
        if len(tokens) > 0 && tokens[0] =~ '^\d\+$'
            return tokens[0]
        endif
    endif
    return '100644'
enddef

# Constraint: Stage buffer uses BufWriteCmd to directly write object to Git index.
export def SaveStageBuffer(repo_root: string, rel_file_path: string, bufnr: number)
    var lines: list<string> = getbufline(bufnr, 1, '$')
    var content: string = join(lines, "\n") .. "\n"

    var hash: string = trim(system('git -C ' .. fnameescape(repo_root) .. ' hash-object -w --stdin', content))
    if v:shell_error != 0 || len(hash) != 40
        notify.Error('Failed to write git object: ' .. hash)
        return
    endif

    var mode: string = GetIndexMode(repo_root, rel_file_path)
    var update_cmd: string = printf('git -C %s update-index --cacheinfo %s,%s,%s',
        fnameescape(repo_root),
        fnameescape(mode),
        fnameescape(hash),
        fnameescape(rel_file_path))
    var update_out: string = system(update_cmd)
    if v:shell_error != 0
        notify.Error('Failed to update index: ' .. update_out)
        return
    endif

    setbufvar(bufnr, '&modified', 0)
    notify.Info('Staged: ' .. rel_file_path)

    if !empty(current_session) && type(get(current_session, 'OnSave', null)) == v:t_func
        current_session.OnSave()
    endif
enddef

export def OnBufWrite()
    var repo_root: string = get(b:, 'gitu_repo_root', '')
    var rel_file_path: string = get(b:, 'gitu_rel_file_path', '')
    if repo_root != '' && rel_file_path != ''
        SaveStageBuffer(repo_root, rel_file_path, bufnr('%'))
    endif
enddef

export def Close3Way()
    if empty(current_session)
        return
    endif
    var session = current_session
    current_session = {}

    diffoff!

    for winid in [session.head_winid, session.stage_winid, session.current_winid]
        if winid > 0 && win_id2win(winid) > 0
            win_execute(winid, 'diffoff')
            win_execute(winid, 'close!')
        endif
    endfor

    if session.status_winid > 0 && win_id2win(session.status_winid) > 0
        setwinvar(session.status_winid, '&winfixheight', 0)
        win_gotoid(session.status_winid)
        silent! only
    endif

    if type(session.OnClose) == v:t_func
        session.OnClose()
    endif
enddef

export def IsActive(): bool
    return !empty(current_session) && get(current_session, 'stage_winid', -1) > 0 && win_id2win(current_session.stage_winid) > 0
enddef

export def MoveView(direction: number, count: number = 1)
    if !IsActive()
        return
    endif
    var scroll_char = direction > 0 ? "\<C-e>" : "\<C-y>"
    var feed_cmd = printf('call feedkeys("%d%s", "xt")', count, scroll_char)
    win_execute(current_session.stage_winid, feed_cmd)
    redraw
enddef

export def Open3Way(repo_root: string, rel_file_path: string, status_winid: number = -1, OnClose: any = null, OnSave: any = null)
    var full_path: string = repo_root .. '/' .. rel_file_path
    if !filereadable(full_path)
        notify.Error('File not found: ' .. rel_file_path)
        return
    endif

    Close3Way()

    var head_out: string = system('git -C ' .. fnameescape(repo_root) .. ' show HEAD:' .. fnameescape(rel_file_path))
    var head_lines: list<string> = (v:shell_error == 0) ? split(head_out, "\n", 1) : ['']
    if empty(head_lines)
        head_lines = ['']
    endif

    var stage_out: string = system('git -C ' .. fnameescape(repo_root) .. ' show :' .. fnameescape(rel_file_path))
    var stage_lines: list<string> = (v:shell_error == 0) ? split(stage_out, "\n", 1) : copy(head_lines)
    if empty(stage_lines)
        stage_lines = ['']
    endif

    if status_winid > 0 && win_id2win(status_winid) > 0
        win_gotoid(status_winid)
        silent! only
    endif

    var status_height: number = get(g:, 'gitu_status_height', 15)
    if status_height > 0 && status_winid > 0 && win_id2win(status_winid) > 0
        setwinvar(status_winid, '&winfixheight', 1)
    endif

    keepjumps botright new
    var head_winid: number = win_getid()
    var head_bufnr: number = buffer.InitCurrentScratch('', '[GitU:HEAD] ' .. rel_file_path)
    buffer.SetLines(head_bufnr, head_lines)
    setlocal nomodifiable
    clearjumps
    diffthis
    nnoremap <buffer> <silent> q <ScriptCmd>Close3Way()<CR>
    nnoremap <buffer> <silent> <C-j> <ScriptCmd>MoveView(1, v:count1)<CR>
    nnoremap <buffer> <silent> <C-k> <ScriptCmd>MoveView(-1, v:count1)<CR>

    keepjumps rightbelow vnew
    var stage_winid: number = win_getid()
    var stage_bufnr: number = bufnr('%')
    setlocal buftype=acwrite
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nobuflisted
    silent! execute 'keepjumps keepalt noautocmd file ' .. fnameescape('[GitU:STAGE] ' .. rel_file_path)
    setbufline(stage_bufnr, 1, stage_lines)
    setlocal nomodified
    clearjumps
    diffthis

    b:gitu_repo_root = repo_root
    b:gitu_rel_file_path = rel_file_path

    augroup GitUStageSave
        autocmd! * <buffer>
        autocmd BufWriteCmd <buffer> OnBufWrite()
        autocmd BufWinLeave <buffer> Close3Way()
    augroup END

    nnoremap <buffer> <silent> q <ScriptCmd>Close3Way()<CR>
    nnoremap <buffer> <silent> <C-j> <ScriptCmd>MoveView(1, v:count1)<CR>
    nnoremap <buffer> <silent> <C-k> <ScriptCmd>MoveView(-1, v:count1)<CR>

    keepjumps rightbelow vnew
    var current_winid: number = win_getid()
    execute 'keepjumps keepalt edit ' .. fnameescape(full_path)
    diffthis
    nnoremap <buffer> <silent> q <ScriptCmd>Close3Way()<CR>
    nnoremap <buffer> <silent> <C-j> <ScriptCmd>MoveView(1, v:count1)<CR>
    nnoremap <buffer> <silent> <C-k> <ScriptCmd>MoveView(-1, v:count1)<CR>

    var target_filetype: string = &filetype
    if target_filetype == ''
        filetype detect
        target_filetype = &filetype
    endif

    if target_filetype != ''
        win_execute(head_winid, 'setlocal filetype=' .. target_filetype)
        win_execute(stage_winid, 'setlocal filetype=' .. target_filetype)
    else
        win_execute(head_winid, 'filetype detect')
        win_execute(stage_winid, 'filetype detect')
    endif

    if status_height > 0 && status_winid > 0 && win_id2win(status_winid) > 0
        win_execute(status_winid, 'resize ' .. string(status_height))
    endif

    current_session = {
        status_winid: status_winid,
        head_winid: head_winid,
        stage_winid: stage_winid,
        current_winid: current_winid,
        OnClose: OnClose,
        OnSave: OnSave,
    }

    win_gotoid(stage_winid)
enddef
