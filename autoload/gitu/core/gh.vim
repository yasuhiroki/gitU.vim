vim9script

import autoload 'gitu/core/job.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/log/github.vim'

def GetExecutable(): string
    return get(g:, 'gitu_gh_executable', 'gh')
enddef

export def IsAvailable(): bool
    return executable(GetExecutable()) == 1
enddef

export def EnsureAvailable(): bool
    if !IsAvailable()
        notify.Error('gh (GitHub CLI) is not installed or not in PATH.')
        return false
    endif
    return true
enddef

export def Run(args: list<string>, opts: dict<any> = {}): number
    var cmd: list<string> = [GetExecutable()] + args
    var run_opts: dict<any> = copy(opts)

    var env: dict<string> = {
        GH_PAGER: 'cat',
        NO_COLOR: '1',
        CLICOLOR: '0',
    }
    if has_key(opts, 'env') && type(opts.env) == v:t_dict
        extend(env, opts.env)
    endif
    run_opts.env = env

    return job.Start(cmd, run_opts)
enddef

export def ResolveRepoOwner(cwd: string): string
    var repo_url = github.GetGitHubRepoUrl(cwd)
    if repo_url == ''
        return ''
    endif
    var matches = matchlist(repo_url, '\vgithub\.com/([^/]+)/([^/]+)$')
    if len(matches) >= 2 && matches[1] != ''
        return matches[1]
    endif
    return ''
enddef

export def Stop(id: number)
    job.Stop(id)
enddef

export def StopByKey(task_key: string)
    job.StopByKey(task_key)
enddef
