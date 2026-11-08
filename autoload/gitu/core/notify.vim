vim9script

export def Info(message: string)
    if message != ''
        echomsg message
    endif
enddef

export def Warn(message: string)
    if message == ''
        return
    endif
    echohl WarningMsg
    echomsg message
    echohl None
enddef

export def Error(message: string)
    if message == ''
        return
    endif
    echohl ErrorMsg
    echomsg message
    echohl None
enddef

export def InfoLines(lines: list<string>)
    for line in lines
        echomsg line
    endfor
enddef

export def ErrorLines(header: string, lines: list<string>)
    echohl ErrorMsg
    if header != ''
        echomsg header
    endif
    for line in lines
        echomsg line
    endfor
    echohl None
enddef
