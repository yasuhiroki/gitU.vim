vim9script

export def InitCurrentScratch(filetype: string, buf_name: string = ''): number
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    if buf_name != ''
        silent! execute 'noautocmd file ' .. fnameescape(buf_name)
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
    setbufvar(bufnr, '&modifiable', 1)
    silent! deletebufline(bufnr, 1, '$')
    setbufline(bufnr, 1, empty(lines) ? [''] : lines)
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
