vim9script

export def InitCurrentScratch(filetype: string, buf_name: string = '', bufhidden: string = 'wipe'): number
    setlocal buftype=nofile
    execute 'setlocal bufhidden=' .. bufhidden
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    if buf_name != ''
        silent! execute 'keepjumps keepalt noautocmd file ' .. fnameescape(buf_name)
    endif
    if filetype != ''
        execute 'setlocal filetype=' .. filetype
    endif
    return bufnr('%')
enddef

export def SetLines(bufnr: number, lines: list<string>)
    if bufnr <= 0 || !bufexists(bufnr)
        return
    endif
    var target_lines = empty(lines) ? [''] : lines
    setbufvar(bufnr, '&modifiable', 1)
    setbufline(bufnr, 1, target_lines)
    var old_count = len(getbufline(bufnr, 1, '$'))
    if old_count > len(target_lines)
        silent! deletebufline(bufnr, len(target_lines) + 1, '$')
    endif
    setbufvar(bufnr, '&modifiable', 0)
enddef

export def AppendLines(bufnr: number, lnum: number, lines: list<string>)
    if bufnr <= 0 || !bufexists(bufnr) || empty(lines)
        return
    endif
    setbufvar(bufnr, '&modifiable', 1)
    appendbufline(bufnr, lnum, lines)
    setbufvar(bufnr, '&modifiable', 0)
enddef

export def ResetWindowTop(winid: number)
    if winid > 0 && win_id2win(winid) > 0
        win_execute(winid, 'normal! gg0')
    endif
enddef

export def CloseTabOrReset()
    if tabpagenr('$') > 1
        tabclose
    else
        silent! only
        enew
    endif
enddef
