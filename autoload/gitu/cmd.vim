vim9script

import autoload 'gitu/git.vim'
import autoload 'gitu/log.vim'
import autoload 'gitu/status.vim'

export var last_result: dict<any> = {}

export def ClearLastResult()
    last_result = {}
enddef

var subcommands: list<string> = [
    'add',
    'blame',
    'branch',
    'checkout',
    'cherry-pick',
    'clean',
    'clone',
    'commit',
    'diff',
    'fetch',
    'init',
    'log',
    'merge',
    'pull',
    'push',
    'rebase',
    'remote',
    'reset',
    'restore',
    'show',
    'stash',
    'status',
    'switch',
    'tag',
]

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var before_cursor = cmd_line[0 : cursor_pos - 1]
    var parts = split(before_cursor, '\s\+', 1)

    if len(parts) <= 2
        if arg_lead == ''
            return copy(subcommands)
        endif
        return filter(copy(subcommands), (_, val: string): bool => stridx(val, arg_lead) == 0)
    endif

    var subcmd = parts[1]

    if subcmd == 'stash' && len(parts) == 3
        var stash_cmds = ['apply', 'branch', 'clear', 'drop', 'list', 'pop', 'push', 'show']
        if arg_lead == ''
            return stash_cmds
        endif
        return filter(stash_cmds, (_, val: string): bool => stridx(val, arg_lead) == 0)
    endif

    if subcmd == 'remote' && len(parts) == 3
        var remote_cmds = ['add', 'get-url', 'prune', 'remove', 'rename', 'set-head', 'set-url', 'show', 'update']
        if arg_lead == ''
            return remote_cmds
        endif
        return filter(remote_cmds, (_, val: string): bool => stridx(val, arg_lead) == 0)
    endif

    if subcmd =~ '\v^(checkout|switch|branch|merge|rebase|diff|log)$'
        var buf_name = expand('%')
        var buf_dir = (buf_name != '' && filereadable(expand('%:p'))) ? expand('%:p:h') : ''
        var cwd = (buf_dir != '' && isdirectory(buf_dir)) ? buf_dir : getcwd()
        var refs_out = system('git -C ' .. shellescape(cwd) .. ' branch -a --format="%(refname:short)"')
        if v:shell_error == 0 && refs_out != ''
            var refs = split(refs_out, "\n")
            if arg_lead == ''
                return refs
            endif
            return filter(refs, (_, val: string): bool => stridx(val, arg_lead) == 0)
        endif
    endif

    return []
enddef

def OnCmdExit(cmd_str: string, res: dict<any>)
    last_result = res
    if res.status != 0
        echohl ErrorMsg
        echomsg cmd_str .. ' failed (exit ' .. string(res.status) .. '):'
        var err_lines = copy(res.stderr)
        extend(err_lines, res.stdout)
        for line in err_lines
            echomsg line
        endfor
        echohl None
    else
        var out_lines = copy(res.stdout)
        extend(out_lines, res.stderr)
        if empty(out_lines)
            echomsg cmd_str .. ' completed.'
        else
            for line in out_lines
                echomsg line
            endfor
        endif
    endif

    status.RefreshAll()
    log.RefreshAll()
enddef

def OnRepoResolved(args: list<string>, repo_root: string, stderr: list<string>)
    if repo_root == ''
        echohl ErrorMsg
        echomsg empty(stderr) ? 'Not a git repository.' : join(stderr, ' ')
        echohl None
        last_result = { status: 128, stdout: [], stderr: empty(stderr) ? ['Not a git repository.'] : stderr }
        return
    endif

    var cmd_str = 'git ' .. join(args, ' ')
    echomsg 'Executing: ' .. cmd_str .. ' ...'

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

    var buf_name: string = expand('%')
    var buf_dir: string = (buf_name != '') ? expand('%:p:h') : ''
    var initial_cwd: string = (buf_dir != '' && isdirectory(buf_dir)) ? buf_dir : getcwd()

    git.ResolveRepoRoot(initial_cwd, (repo_root: string, stderr: list<string>) => {
        OnRepoResolved(args, repo_root, stderr)
    })
enddef
