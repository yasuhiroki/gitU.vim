vim9script

import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'

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
    var normalized = tolower(trim(query))
    if normalized == ''
        return ''
    endif

    if has_key(registry, normalized)
        return normalized
    endif

    for [name, item] in items(registry)
        if get(item, 'key', '') ==# normalized || get(item, 'alias', '') ==# normalized
            return name
        endif
    endfor

    var prefix_matches = filter(keys(registry), (_, name: string): bool => stridx(name, normalized) == 0)
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
        var header = printf('Fixup commit failed for %s (exit %d):', hash[0 : 6], commit_res.status)
        var err_lines = empty(commit_res.stderr) ? commit_res.stdout : commit_res.stderr
        notify.ErrorLines(header, err_lines)
    else
        var out_lines = empty(commit_res.stdout) ? commit_res.stderr : commit_res.stdout
        notify.InfoLines(out_lines)
        notify.Info(printf('Created fixup commit for %s', hash[0 : 6]))
    endif

    view.RefreshAll()
enddef

def OnFixupDiffExit(hash: string, cwd: string, diff_res: dict<any>)
    if diff_res.status != 0
        notify.Error('Failed to check staged changes: ' .. join(diff_res.stderr, ' '))
        last_action_result = { status: diff_res.status, action: 'fixup', message: 'diff failed' }
        return
    endif

    var staged_files = filter(diff_res.stdout, (_, f: string): bool => trim(f) != '')
    if empty(staged_files)
        notify.Warn('No staged changes to commit for fixup. Please stage changes with "<<" or "pp" first.')
        last_action_result = { status: 1, action: 'fixup', message: 'No staged changes' }
        return
    endif

    notify.Info(printf('Creating fixup commit for %s (%s)...', hash[0 : 6], join(staged_files, ', ')))

    git.Run(['commit', '--fixup=' .. hash], {
        cwd: cwd,
        on_exit: (res: dict<any>) => OnFixupCommitExit(hash, res),
    })
enddef

def ExecuteFixup(context: dict<any>)
    var hash: string = get(context, 'hash', '')
    var cwd: string = get(context, 'cwd', '')
    if hash == '' || cwd == ''
        notify.Warn('Invalid context for fixup: missing commit hash or repository path')
        last_action_result = { status: -1, action: 'fixup', message: 'Missing hash or cwd' }
        return
    endif

    git.Run(['diff', '--cached', '--name-only'], {
        cwd: cwd,
        on_exit: (res: dict<any>) => OnFixupDiffExit(hash, cwd, res),
    })
enddef

def ExecuteRebaseInteractive(context: dict<any>)
    var hash: string = get(context, 'hash', '')
    var cwd: string = get(context, 'cwd', '')
    if hash == '' || cwd == ''
        notify.Warn('Invalid context for interactive rebase: missing commit hash or repository path')
        last_action_result = { status: -1, action: 'rebase', message: 'Missing hash or cwd' }
        return
    endif

    if !has('terminal')
        notify.Error('Terminal support (+terminal) is required for interactive rebase')
        last_action_result = { status: -1, action: 'rebase', message: 'No terminal support' }
        return
    endif

    systemlist(['git', '-C', cwd, 'rev-parse', '--verify', hash .. '^'])
    var has_parent = (v:shell_error == 0)
    var target = has_parent ? (hash .. '^') : '--root'

    var cmd = ['git', 'rebase', '-i', target]

    var env_dict: dict<string> = {}
    var cur_env = environ()
    if has_key(cur_env, 'GIT_SEQUENCE_EDITOR') && cur_env['GIT_SEQUENCE_EDITOR'] != ''
        env_dict['GIT_SEQUENCE_EDITOR'] = cur_env['GIT_SEQUENCE_EDITOR']
    else
        env_dict['GIT_SEQUENCE_EDITOR'] = v:progpath
    endif

    if has_key(cur_env, 'GIT_EDITOR') && cur_env['GIT_EDITOR'] != ''
        env_dict['GIT_EDITOR'] = cur_env['GIT_EDITOR']
    else
        env_dict['GIT_EDITOR'] = v:progpath
    endif

    tabnew
    var term_winid = win_getid()

    var opts = {
        curwin: 1,
        cwd: cwd,
        env: env_dict,
        term_name: 'git-rebase',
        exit_cb: (_job: job, status: number) => {
            last_action_result = { status: status, action: 'rebase' }
            if status == 0
                if win_id2win(term_winid) > 0
                    var tab_info = win_id2tabwin(term_winid)
                    if tab_info[0] > 0
                        if tabpagenr('$') > 1
                            silent! execute 'tabclose ' .. string(tab_info[0])
                        else
                            silent! execute 'bwipeout! ' .. string(winbufnr(term_winid))
                        endif
                    endif
                endif
                notify.Info('Interactive rebase completed successfully')
            else
                notify.Warn(printf('Interactive rebase exited with status %d', status))
            endif
            view.RefreshAll()
        },
    }

    term_start(cmd, opts)
enddef

def InitBuiltins()
    Register('fixup', {
        name: 'fixup',
        description: 'Create fixup commit for selected commit with staged changes',
        key: 'f',
        execute: (context: dict<any>) => ExecuteFixup(context),
    })
    Register('rebase', {
        name: 'rebase',
        description: 'Interactive rebase onto parent of selected commit (or --root)',
        key: 'r',
        alias: 'ri',
        execute: (context: dict<any>) => ExecuteRebaseInteractive(context),
    })
enddef

InitBuiltins()

export def Execute(action_name: string, context: dict<any>)
    var resolved = Resolve(action_name)
    if resolved == '' || !has_key(registry, resolved)
        notify.Warn('Unknown action: ' .. action_name)
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

    var choice = input(prompt_str, '', 'customlist,gitu#log#action#Complete')
    choice = trim(choice)
    if choice == ''
        return
    endif

    Execute(choice, context)
enddef
