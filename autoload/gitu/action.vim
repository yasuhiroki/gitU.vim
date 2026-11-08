vim9script

import autoload 'gitu/core/git.vim'
import autoload 'gitu/log.vim'
import autoload 'gitu/status.vim'

export var last_action_result: dict<any> = {}

export def ClearLastActionResult()
    last_action_result = {}
enddef

var registry: dict<dict<any>> = {}

export def Register(name: string, def_dict: dict<any>)
    registry[name] = def_dict
enddef

export def Get(name: string): dict<any>
    return get(registry, name, {})
enddef

export def List(): list<string>
    return sort(keys(registry))
enddef

export def Resolve(query: string): string
    var q = tolower(trim(query))
    if q == ''
        return ''
    endif

    # Exact match
    if has_key(registry, q)
        return q
    endif

    # Match by key shortcut
    for [name, item] in items(registry)
        if get(item, 'key', '') ==# q
            return name
        endif
    endfor

    # Unique prefix match
    var prefix_matches = filter(keys(registry), (_, name: string): bool => stridx(name, q) == 0)
    if len(prefix_matches) == 1
        return prefix_matches[0]
    endif

    return ''
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var names = List()
    if arg_lead == ''
        return names
    endif
    return filter(names, (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef

def OnFixupCommitExit(hash: string, commit_res: dict<any>)
    last_action_result = copy(commit_res)
    last_action_result.action = 'fixup'

    if commit_res.status != 0
        echohl ErrorMsg
        echomsg printf('Fixup commit failed for %s (exit %d):', hash[0 : 6], commit_res.status)
        var err_lines = empty(commit_res.stderr) ? commit_res.stdout : commit_res.stderr
        for line in err_lines
            echomsg line
        endfor
        echohl None
    else
        var out_lines = empty(commit_res.stdout) ? commit_res.stderr : commit_res.stdout
        for line in out_lines
            echomsg line
        endfor
        echomsg printf('Created fixup commit for %s', hash[0 : 6])
    endif

    log.RefreshAll()
    status.RefreshAll()
enddef

def OnFixupDiffExit(hash: string, cwd: string, diff_res: dict<any>)
    if diff_res.status != 0
        echohl ErrorMsg
        echomsg 'Failed to check staged changes: ' .. join(diff_res.stderr, ' ')
        echohl None
        last_action_result = { status: diff_res.status, action: 'fixup', message: 'diff failed' }
        return
    endif

    var staged_files = filter(diff_res.stdout, (_, f: string): bool => trim(f) != '')
    if empty(staged_files)
        echohl WarningMsg
        echomsg 'No staged changes to commit for fixup. Please stage changes with "<<" or "pp" first.'
        echohl None
        last_action_result = { status: 1, action: 'fixup', message: 'No staged changes' }
        return
    endif

    echomsg printf('Creating fixup commit for %s (%s)...', hash[0 : 6], join(staged_files, ', '))

    git.Run(['commit', '--fixup=' .. hash], {
        cwd: cwd,
        on_exit: (res: dict<any>) => OnFixupCommitExit(hash, res),
    })
enddef

def ExecuteFixup(context: dict<any>)
    var hash: string = get(context, 'hash', '')
    var cwd: string = get(context, 'cwd', '')
    if hash == '' || cwd == ''
        echohl WarningMsg
        echomsg 'Invalid context for fixup: missing commit hash or repository path'
        echohl None
        last_action_result = { status: -1, action: 'fixup', message: 'Missing hash or cwd' }
        return
    endif

    git.Run(['diff', '--cached', '--name-only'], {
        cwd: cwd,
        on_exit: (res: dict<any>) => OnFixupDiffExit(hash, cwd, res),
    })
enddef

def InitBuiltins()
    Register('fixup', {
        name: 'fixup',
        description: 'Create fixup commit for selected commit with staged changes',
        key: 'f',
        execute: (context: dict<any>) => ExecuteFixup(context),
    })
enddef

InitBuiltins()

export def Execute(action_name: string, context: dict<any>)
    var resolved = Resolve(action_name)
    if resolved == '' || !has_key(registry, resolved)
        echohl WarningMsg
        echomsg 'Unknown action: ' .. action_name
        echohl None
        last_action_result = { status: -1, action: action_name, message: 'Unknown action' }
        return
    endif

    var action_def = registry[resolved]
    var Fn = action_def.execute
    Fn(context)
enddef

export def Prompt(context: dict<any>)
    var action_names = List()
    var hash_label = (has_key(context, 'hash') && context.hash != '') ? context.hash[0 : 6] : ''
    var prompt_str = printf('GitU Action [%s] for %s: ', join(action_names, '/'), hash_label)

    var choice = input(prompt_str, '', 'customlist,gitu#action#Complete')
    choice = trim(choice)
    if choice == ''
        return
    endif

    Execute(choice, context)
enddef
