vim9script

var refreshers: dict<func()> = {}

export def GetKey(view_id: number): string
    return string(view_id)
enddef

export def GetCurrentId(): number
    if exists('b:gitu_view_id')
        return b:gitu_view_id
    endif
    if exists('t:gitu_view_id')
        return t:gitu_view_id
    endif
    return -1
enddef

export def RegisterRefresher(name: string, Refresher: func())
    refreshers[name] = Refresher
enddef

export def RefreshAll()
    for Refresher in values(refreshers)
        Refresher()
    endfor
enddef
