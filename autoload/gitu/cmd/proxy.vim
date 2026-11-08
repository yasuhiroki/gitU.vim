vim9script

import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/status/view.vim' as status
import autoload 'gitu/cmd/complete.vim'

export var last_result: dict<any> = {}

export def ClearLastResult()
    last_result = {}
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return complete.Complete(arg_lead, cmd_line, cursor_pos)
enddef

def OnCmdExit(cmd_str: string, res: dict<any>)
    last_result = res
    if res.status != 0
        var header = cmd_str .. ' failed (exit ' .. string(res.status) .. '):'
        var err_lines = copy(res.stderr)
        extend(err_lines, res.stdout)
        notify.ErrorLines(header, err_lines)
    else
        var out_lines = copy(res.stdout)
        extend(out_lines, res.stderr)
        if empty(out_lines)
            notify.Info(cmd_str .. ' completed.')
        else
            notify.InfoLines(out_lines)
        endif
    endif

    view.RefreshAll()
enddef

def OnRepoResolved(args: list<string>, repo_root: string, stderr: list<string>)
    if repo_root == ''
        notify.Error(empty(stderr) ? 'Not a git repository.' : join(stderr, ' '))
        last_result = { status: 128, stdout: [], stderr: empty(stderr) ? ['Not a git repository.'] : stderr }
        return
    endif

    var cmd_str = 'git ' .. join(args, ' ')
    notify.Info('Executing: ' .. cmd_str .. ' ...')

    git.Run(args, {
        cwd: repo_root,
        on_exit: (res: dict<any>) => OnCmdExit(cmd_str, res),
    })
enddef

export def Execute(...args: list<string>)
    if empty(args)
        status.Open()
        return
    endif

    var initial_cwd: string = git.ResolveInitialCwd()

    git.ResolveRepoRoot(initial_cwd, (repo_root: string, stderr: list<string>) => {
        OnRepoResolved(args, repo_root, stderr)
    })
enddef
