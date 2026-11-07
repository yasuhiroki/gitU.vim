vim9script

var next_job_id: number = 0
var active_jobs: dict<dict<any>> = {}
var key_to_job: dict<number> = {}

# Constraint: Vim job exit_cb and channel close_cb may fire in either order.
# Both must finish before invoking on_exit and cleaning up state.
def FinishIfReady(id: number)
    var id_key: string = string(id)
    if !has_key(active_jobs, id_key)
        return
    endif
    var state = active_jobs[id_key]
    if !state.closed || !state.exited
        return
    endif

    remove(active_jobs, id_key)
    if state.task_key != '' && get(key_to_job, state.task_key, -1) == id
        remove(key_to_job, state.task_key)
    endif

    if state.cancelled
        return
    endif

    if has_key(state.opts, 'on_exit') && type(state.opts.on_exit) == v:t_func
        var OnExit = state.opts.on_exit
        OnExit({
            id: id,
            status: state.exit_status,
            stdout: state.stdout,
            stderr: state.stderr,
            cmd: state.cmd,
        })
    endif
enddef

export def Start(cmd: list<string>, opts: dict<any> = {}): number
    var task_key: string = get(opts, 'task_key', '')
    if task_key != ''
        StopByKey(task_key)
    endif

    next_job_id += 1
    var id: number = next_job_id
    var id_key: string = string(id)

    var state: dict<any> = {
        id: id,
        cmd: cmd,
        opts: opts,
        task_key: task_key,
        stdout: [],
        stderr: [],
        closed: false,
        exited: false,
        cancelled: false,
        exit_status: -1,
    }
    active_jobs[id_key] = state
    if task_key != ''
        key_to_job[task_key] = id
    endif

    var job_opts: dict<any> = {
        in_io: 'null',
        out_mode: 'nl',
        err_mode: 'nl',
        out_cb: (ch: channel, msg: string) => {
            if !has_key(active_jobs, id_key) || active_jobs[id_key].cancelled
                return
            endif
            add(active_jobs[id_key].stdout, msg)
            if has_key(opts, 'on_stdout') && type(opts.on_stdout) == v:t_func
                var OnStdout = opts.on_stdout
                OnStdout([msg])
            endif
        },
        err_cb: (ch: channel, msg: string) => {
            if !has_key(active_jobs, id_key) || active_jobs[id_key].cancelled
                return
            endif
            add(active_jobs[id_key].stderr, msg)
            if has_key(opts, 'on_stderr') && type(opts.on_stderr) == v:t_func
                var OnStderr = opts.on_stderr
                OnStderr([msg])
            endif
        },
        close_cb: (ch: channel) => {
            if !has_key(active_jobs, id_key)
                return
            endif
            active_jobs[id_key].closed = true
            FinishIfReady(id)
        },
        exit_cb: (j: job, status: number) => {
            if !has_key(active_jobs, id_key)
                return
            endif
            active_jobs[id_key].exited = true
            active_jobs[id_key].exit_status = status
            FinishIfReady(id)
        },
    }

    var cwd: string = get(opts, 'cwd', '')
    if cwd != '' && isdirectory(cwd)
        job_opts.cwd = cwd
    endif

    if has_key(opts, 'env') && type(opts.env) == v:t_dict
        job_opts.env = opts.env
    endif

    var j: job = job_start(cmd, job_opts)
    state.job = j

    if job_status(j) == 'fail'
        remove(active_jobs, id_key)
        if task_key != '' && get(key_to_job, task_key, -1) == id
            remove(key_to_job, task_key)
        endif
        if has_key(opts, 'on_exit') && type(opts.on_exit) == v:t_func
            var OnExit = opts.on_exit
            OnExit({
                id: id,
                status: -1,
                stdout: [],
                stderr: ['Failed to start job: ' .. join(cmd, ' ')],
                cmd: cmd,
            })
        endif
        return -1
    endif

    return id
enddef

export def Stop(id: number)
    var id_key: string = string(id)
    if !has_key(active_jobs, id_key)
        return
    endif
    var state = active_jobs[id_key]
    state.cancelled = true
    if state.task_key != '' && get(key_to_job, state.task_key, -1) == id
        remove(key_to_job, state.task_key)
    endif
    if has_key(state, 'job') && job_status(state.job) == 'run'
        job_stop(state.job)
    endif
    remove(active_jobs, id_key)
enddef

export def StopByKey(task_key: string)
    if task_key == '' || !has_key(key_to_job, task_key)
        return
    endif
    var id: number = key_to_job[task_key]
    Stop(id)
enddef

export def StopAll()
    for id_key in keys(active_jobs)
        Stop(str2nr(id_key))
    endfor
enddef

export def IsRunning(id: number): bool
    var id_key: string = string(id)
    return has_key(active_jobs, id_key) && !active_jobs[id_key].cancelled
enddef
