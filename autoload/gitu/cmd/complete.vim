vim9script

import autoload 'gitu/core/git.vim'

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

var stash_subcommands: list<string> = [
    'apply',
    'branch',
    'clear',
    'drop',
    'list',
    'pop',
    'push',
    'show',
]

var remote_subcommands: list<string> = [
    'add',
    'get-url',
    'prune',
    'remove',
    'rename',
    'set-head',
    'set-url',
    'show',
    'update',
]

def FilterPrefix(candidates: list<string>, arg_lead: string): list<string>
    if arg_lead == ''
        return copy(candidates)
    endif
    return filter(copy(candidates), (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var before_cursor = cmd_line[0 : cursor_pos - 1]
    var parts = split(before_cursor, '\s\+', 1)

    if len(parts) <= 2
        return FilterPrefix(subcommands, arg_lead)
    endif

    var subcmd = parts[1]

    if subcmd == 'stash' && len(parts) == 3
        return FilterPrefix(stash_subcommands, arg_lead)
    endif

    if subcmd == 'remote' && len(parts) == 3
        return FilterPrefix(remote_subcommands, arg_lead)
    endif

    if subcmd =~ '\v^(checkout|switch|branch|merge|rebase|diff|log)$'
        var cwd = git.ResolveInitialCwd()
        var refs_out = system('git -C ' .. shellescape(cwd) .. ' branch -a --format="%(refname:short)"')
        if v:shell_error == 0 && refs_out != ''
            var refs = split(refs_out, "\n")
            return FilterPrefix(refs, arg_lead)
        endif
    endif

    return []
enddef
