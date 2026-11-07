vim9script

import autoload 'gitu/job.vim'

export def Run(args: list<string>, opts: dict<any> = {}): number
    var cmd: list<string> = ['git', '--no-pager', '-c', 'color.ui=false'] + args
    var run_opts: dict<any> = copy(opts)

    var env: dict<string> = {
        GIT_OPTIONAL_LOCKS: '0',
        GIT_PAGER: 'cat',
    }
    if has_key(opts, 'env') && type(opts.env) == v:t_dict
        extend(env, opts.env)
    endif
    run_opts.env = env

    return job.Start(cmd, run_opts)
enddef

export def ResolveRepoRoot(cwd: string, Callback: func(string, list<string>)): number
    return Run(['rev-parse', '--show-toplevel'], {
        cwd: cwd,
        on_exit: (res: dict<any>) => {
            if res.status == 0 && len(res.stdout) > 0
                Callback(trim(res.stdout[0]), [])
            else
                Callback('', res.stderr)
            endif
        },
    })
enddef

export def Stop(id: number)
    job.Stop(id)
enddef

export def StopByKey(task_key: string)
    job.StopByKey(task_key)
enddef
