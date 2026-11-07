vim9script

import autoload 'gitu/buffer.vim'
import autoload 'gitu/stage.vim'

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
        echohl ErrorMsg
        echomsg 'Failed to write git object: ' .. hash
        echohl None
        return
    endif

    var mode: string = GetIndexMode(repo_root, rel_file_path)
    var update_cmd: string = printf('git -C %s update-index --cacheinfo %s,%s,%s',
        fnameescape(repo_root),
        fnameescape(mode),
        fnameescape(hash),
        fnameescape(rel_file_path))
    var res: string = system(update_cmd)
    if v:shell_error != 0
        echohl ErrorMsg
        echomsg 'Failed to update index: ' .. res
        echohl None
        return
    endif

    setbufvar(bufnr, '&modified', 0)
    echomsg 'Staged: ' .. rel_file_path
enddef

export def OnBufWrite()
    var repo_root: string = get(b:, 'gitu_repo_root', '')
    var rel_file_path: string = get(b:, 'gitu_rel_file_path', '')
    if repo_root != '' && rel_file_path != ''
        SaveStageBuffer(repo_root, rel_file_path, bufnr('%'))
    endif
enddef

export def Close3Way(OnClose: any)
    diffoff!
    if tabpagenr('$') > 1
        tabclose
    else
        silent! only
        enew
    endif
    if type(OnClose) == v:t_func
        OnClose()
    endif
enddef

export def Open3Way(repo_root: string, rel_file_path: string, OnClose: any = null)
    var full_path: string = repo_root .. '/' .. rel_file_path
    if !filereadable(full_path)
        echohl ErrorMsg
        echomsg 'File not found: ' .. rel_file_path
        echohl None
        return
    endif

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

    tabnew

    # Panel 1 (Left): HEAD
    var head_bufnr: number = buffer.InitCurrentScratch('gitu-stage-head', '[GitU:HEAD: ' .. rel_file_path .. ']')
    buffer.SetLines(head_bufnr, head_lines)
    setlocal nomodifiable
    diffthis
    nnoremap <buffer> <silent> q <ScriptCmd>stage.Close3Way(OnClose)<CR>

    # Panel 2 (Center): STAGE
    rightbelow vnew
    var stage_winid: number = win_getid()
    var stage_bufnr: number = bufnr('%')
    setlocal buftype=acwrite
    setlocal bufhidden=wipe
    setlocal noswapfile
    silent! execute 'noautocmd file ' .. fnameescape('[GitU:STAGE: ' .. rel_file_path .. ']')
    execute 'setlocal filetype=' .. fnamemodify(rel_file_path, ':e')
    setbufline(stage_bufnr, 1, stage_lines)
    setlocal nomodified
    diffthis

    b:gitu_repo_root = repo_root
    b:gitu_rel_file_path = rel_file_path

    augroup GitUStageSave
        autocmd! * <buffer>
        autocmd BufWriteCmd <buffer> stage.OnBufWrite()
    augroup END

    nnoremap <buffer> <silent> q <ScriptCmd>stage.Close3Way(OnClose)<CR>

    # Panel 3 (Right): CURRENT (Worktree file)
    rightbelow vnew
    execute 'edit ' .. fnameescape(full_path)
    diffthis
    nnoremap <buffer> <silent> q <ScriptCmd>stage.Close3Way(OnClose)<CR>

    # Focus Center (STAGE) panel
    win_gotoid(stage_winid)
enddef
