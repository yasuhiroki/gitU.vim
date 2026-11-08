vim9script

var completion_candidates: list<string> = [
    '--amend',
    '-a',
    '--all',
    '--no-verify',
    '-s',
    '--signoff',
    '--allow-empty',
]

export def FilterCommitMessage(lines: list<string>, comment_char: string = '#'): list<string>
    var cleaned: list<string> = []
    var active_char: string = comment_char != '' ? escape(comment_char, '\*^$.~[]') : '#'
    var comment_pattern: string = '^\s*' .. active_char

    for line in lines
        if line !~ comment_pattern
            add(cleaned, line)
        endif
    endfor

    while len(cleaned) > 0 && cleaned[0] =~ '^\s*$'
        remove(cleaned, 0)
    endwhile

    while len(cleaned) > 0 && cleaned[-1] =~ '^\s*$'
        remove(cleaned, -1)
    endwhile

    return cleaned
enddef

export def RequiresStagedChanges(extra_args: list<string>): bool
    var is_amend: bool = index(extra_args, '--amend') >= 0
    var is_all: bool = index(extra_args, '-a') >= 0 || index(extra_args, '--all') >= 0
    var is_empty_ok: bool = index(extra_args, '--allow-empty') >= 0
    return !is_amend && !is_all && !is_empty_ok
enddef

export def BuildCommitTemplate(repo_root: string, extra_args: list<string> = []): list<string>
    var lines: list<string> = []
    var is_amend: bool = index(extra_args, '--amend') >= 0

    if is_amend
        var prev_msg: string = trim(system('git -C ' .. fnameescape(repo_root) .. ' log -n 1 --format=%B HEAD'))
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

    var status_out: string = system('git -C ' .. fnameescape(repo_root) .. ' status')
    if v:shell_error == 0 && status_out != ''
        for line in split(status_out, "\n")
            add(lines, line == '' ? '#' : '# ' .. line)
        endfor
    endif

    return lines
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    if arg_lead == ''
        return copy(completion_candidates)
    endif
    return filter(copy(completion_candidates), (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
