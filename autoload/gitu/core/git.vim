vim9script

import autoload 'gitu/core/job.vim'

# Constraint: expand('%:p:h') on an unnamed or non-file buffer returns the
# startup directory rather than empty string, so check &buftype and expand('%').
export def ResolveInitialCwd(): string
    var buf_name: string = (&buftype == '') ? expand('%') : ''
    var buf_dir: string = (buf_name != '') ? expand('%:p:h') : ''
    if buf_dir != '' && isdirectory(buf_dir)
        return buf_dir
    endif
    return getcwd()
enddef

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
