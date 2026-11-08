vim9script

import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/commit/parser.vim'

var sessions: dict<dict<any>> = {}
var next_session_id: number = 0

def OnCommitExit(tmp_msg_file: string, res: dict<any>)
    delete(tmp_msg_file)
    if res.status != 0
        var error_output: string = empty(res.stderr) ? join(res.stdout, ' ') : join(res.stderr, ' ')
        notify.Error('Commit failed: ' .. error_output)
        return
    endif

    var summary: string = empty(res.stdout) ? 'Commit completed successfully.' : res.stdout[0]
    notify.Info(summary)
    view.RefreshAll()
enddef

def ExecuteCommit(repo_root: string, message_lines: list<string>, extra_args: list<string>)
    var tmp_msg_file: string = tempname()
    writefile(message_lines, tmp_msg_file)

    var cmd_args: list<string> = ['commit', '-F', tmp_msg_file] + extra_args

    git.Run(cmd_args, {
        cwd: repo_root,
        task_key: 'gitu_commit_exec',
        on_exit: (res: dict<any>) => OnCommitExit(tmp_msg_file, res),
    })
enddef

export def OnBufWrite()
    var session_key: string = get(b:, 'gitu_commit_session_key', '')
    if session_key == '' || !has_key(sessions, session_key)
        setlocal nomodified
        return
    endif

    var session = sessions[session_key]
    session.saved = true
    session.saved_lines = getline(1, '$')
    setlocal nomodified
    notify.Info('Commit message saved. Close (:wq) to commit.')
enddef

export def OnBufWipeout()
    var session_key: string = get(b:, 'gitu_commit_session_key', '')
    if session_key == '' || !has_key(sessions, session_key)
        return
    endif

    var session = sessions[session_key]
    remove(sessions, session_key)

    if !session.saved
        notify.Info('Commit aborted.')
        return
    endif

    var cleaned: list<string> = parser.FilterCommitMessage(session.saved_lines)
    if empty(cleaned)
        notify.Warn('Aborting commit due to empty commit message.')
        return
    endif

    ExecuteCommit(session.repo_root, cleaned, session.extra_args)
enddef

def OpenCommitTab(repo_root: string, extra_args: list<string>)
    next_session_id += 1
    var session_id: number = next_session_id
    var session_key: string = string(session_id)

    tabnew
    var winid: number = win_getid()
    var bufnr: number = bufnr('%')

    setlocal buftype=acwrite
    setlocal bufhidden=wipe
    setlocal noswapfile
    silent! execute 'noautocmd file ' .. fnameescape('[GitU:COMMIT_EDITMSG #' .. session_key .. ']')
    setlocal filetype=gitcommit

    var template: list<string> = parser.BuildCommitTemplate(repo_root, extra_args)
    setline(1, template)
    setlocal nomodified
    cursor(1, 1)

    sessions[session_key] = {
        id: session_id,
        repo_root: repo_root,
        extra_args: extra_args,
        bufnr: bufnr,
        winid: winid,
        saved: false,
        saved_lines: [],
    }

    b:gitu_commit_session_key = session_key

    augroup GitUCommitEditor
        autocmd! * <buffer>
        autocmd BufWriteCmd <buffer> OnBufWrite()
        autocmd BufWipeout <buffer> OnBufWipeout()
    augroup END
enddef

export def Open(...extra_args: list<string>)
    var initial_cwd: string = git.ResolveInitialCwd()

    git.ResolveRepoRoot(initial_cwd, (repo_root: string, stderr: list<string>) => {
        if repo_root == ''
            notify.Error(empty(stderr) ? 'Not a git repository.' : join(stderr, ' '))
            return
        endif

        if parser.RequiresStagedChanges(extra_args)
            system('git -C ' .. fnameescape(repo_root) .. ' diff --cached --quiet')
            if v:shell_error == 0
                notify.Warn('nothing to commit (use git add or << in :GitUStatus to stage changes)')
                return
            endif
        endif

        OpenCommitTab(repo_root, extra_args)
    })
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return parser.Complete(arg_lead, cmd_line, cursor_pos)
enddef
