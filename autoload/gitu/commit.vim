vim9script

import autoload 'gitu/buffer.vim'
import autoload 'gitu/git.vim'
import autoload 'gitu/log.vim'
import autoload 'gitu/status.vim'

var sessions: dict<dict<any>> = {}
var next_session_id: number = 0

export def FilterCommitMessage(lines: list<string>, comment_char: string = '#'): list<string>
    var cleaned: list<string> = []
    var pattern: string = '^\s*' .. (comment_char != '' ? escape(comment_char, '\*^$.~[]') : '#')

    for line in lines
        if line =~ pattern
            continue
        endif
        add(cleaned, line)
    endfor

    while len(cleaned) > 0 && cleaned[0] =~ '^\s*$'
        remove(cleaned, 0)
    endwhile

    while len(cleaned) > 0 && cleaned[-1] =~ '^\s*$'
        remove(cleaned, -1)
    endwhile

    return cleaned
enddef

export def BuildCommitTemplate(repo_root: string, extra_args: list<string> = []): list<string>
    var lines: list<string> = []

    var is_amend = index(extra_args, '--amend') >= 0
    if is_amend
        var prev_msg = trim(system('git -C ' .. fnameescape(repo_root) .. ' log -n 1 --format=%B HEAD'))
        if v:shell_error == 0 && prev_msg != ''
            lines = split(prev_msg, "\n")
        endif
        add(lines, '')
    else
        lines = ['', '']
    endif

    add(lines, '# Please enter the commit message for your changes. Lines starting')
    add(lines, '# with ''#'' will be ignored, and an empty message aborts the commit.')
    add(lines, '#')

    var status_out = system('git -C ' .. fnameescape(repo_root) .. ' status')
    if v:shell_error == 0 && status_out != ''
        for line in split(status_out, "\n")
            if line == ''
                add(lines, '#')
            else
                add(lines, '# ' .. line)
            endif
        endfor
    endif

    return lines
enddef

def ExecuteCommit(repo_root: string, message_lines: list<string>, extra_args: list<string>)
    var tmp_msg_file = tempname()
    writefile(message_lines, tmp_msg_file)

    var cmd = ['commit', '-F', tmp_msg_file] + extra_args

    git.Run(cmd, {
        cwd: repo_root,
        task_key: 'gitu_commit_exec',
        on_exit: (res: dict<any>) => {
            delete(tmp_msg_file)
            if res.status != 0
                echohl ErrorMsg
                echomsg 'Commit failed: ' .. (empty(res.stderr) ? join(res.stdout, ' ') : join(res.stderr, ' '))
                echohl None
                return
            endif

            var summary = empty(res.stdout) ? 'Commit completed successfully.' : res.stdout[0]
            echomsg summary

            status.RefreshAll()
            log.RefreshAll()
        },
    })
enddef

export def OnBufWrite()
    var session_key = get(b:, 'gitu_commit_session_key', '')
    if session_key == '' || !has_key(sessions, session_key)
        setlocal nomodified
        return
    endif

    var session = sessions[session_key]
    session.saved = true
    session.saved_lines = getline(1, '$')
    setlocal nomodified
    echomsg 'Commit message saved. Close (:wq) to commit.'
enddef

export def OnBufWipeout()
    var session_key = get(b:, 'gitu_commit_session_key', '')
    if session_key == '' || !has_key(sessions, session_key)
        return
    endif

    var session = sessions[session_key]
    remove(sessions, session_key)

    if !session.saved
        echomsg 'Commit aborted.'
        return
    endif

    var cleaned = FilterCommitMessage(session.saved_lines)
    if empty(cleaned)
        echohl WarningMsg
        echomsg 'Aborting commit due to empty commit message.'
        echohl None
        return
    endif

    ExecuteCommit(session.repo_root, cleaned, session.extra_args)
enddef

def OpenCommitTab(repo_root: string, extra_args: list<string>)
    next_session_id += 1
    var session_id = next_session_id
    var session_key = string(session_id)

    tabnew
    var winid = win_getid()
    var bufnr = bufnr('%')

    setlocal buftype=acwrite
    setlocal bufhidden=wipe
    setlocal noswapfile
    silent! execute 'noautocmd file ' .. fnameescape('[GitU:COMMIT_EDITMSG #' .. session_key .. ']')
    setlocal filetype=gitcommit

    var template = BuildCommitTemplate(repo_root, extra_args)
    setline(1, template)
    setlocal nomodified
    cursor(1, 1)

    var session = {
        id: session_id,
        repo_root: repo_root,
        extra_args: extra_args,
        bufnr: bufnr,
        winid: winid,
        saved: false,
        saved_lines: [],
    }
    sessions[session_key] = session

    b:gitu_commit_session_key = session_key

    augroup GitUCommitEditor
        autocmd! * <buffer>
        autocmd BufWriteCmd <buffer> OnBufWrite()
        autocmd BufWipeout <buffer> OnBufWipeout()
    augroup END
enddef

export def Open(...extra_args: list<string>)
    var buf_dir: string = expand('%:p:h')
    var initial_cwd: string = (buf_dir != '' && isdirectory(buf_dir)) ? buf_dir : getcwd()

    git.ResolveRepoRoot(initial_cwd, (repo_root: string, stderr: list<string>) => {
        if repo_root == ''
            echohl ErrorMsg
            echomsg empty(stderr) ? 'Not a git repository.' : join(stderr, ' ')
            echohl None
            return
        endif

        var is_amend = index(extra_args, '--amend') >= 0
        var is_all = index(extra_args, '-a') >= 0 || index(extra_args, '--all') >= 0
        var is_empty_ok = index(extra_args, '--allow-empty') >= 0
        if !is_amend && !is_all && !is_empty_ok
            system('git -C ' .. fnameescape(repo_root) .. ' diff --cached --quiet')
            if v:shell_error == 0
                echohl WarningMsg
                echomsg 'nothing to commit (use git add or << in :GitUStatus to stage changes)'
                echohl None
                return
            endif
        endif

        OpenCommitTab(repo_root, extra_args)
    })
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var candidates: list<string> = [
        '--amend',
        '-a',
        '--all',
        '--no-verify',
        '-s',
        '--signoff',
        '--allow-empty',
    ]
    if arg_lead == ''
        return candidates
    endif
    return filter(candidates, (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
