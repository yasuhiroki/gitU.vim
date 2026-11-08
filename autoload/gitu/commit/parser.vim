vim9script

var completion_candidates: list<string> = [
    '--amend',
    '-a',
    '--all',
    '-v',
    '--verbose',
    '-t',
    '--template',
    '--no-verify',
    '-s',
    '--signoff',
    '--allow-empty',
]

export def FilterCommitMessage(lines: list<string>, comment_char: string = '#'): list<string>
    var cleaned: list<string> = []
    var active_char: string = comment_char != '' ? escape(comment_char, '\*^$.~[]') : '#'
    var comment_pattern: string = '^\s*' .. active_char
    var scissors_pattern: string = '^\s*' .. active_char .. '\s*-\+\s*>8\s*-\+'

    for line in lines
        if line =~ scissors_pattern
            break
        endif
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

export def ExtractTemplatePath(extra_args: list<string>): string
    for idx in range(len(extra_args))
        var arg = extra_args[idx]
        if arg =~# '^--template='
            return split(arg, '=')[1]
        elseif (arg == '-t' || arg == '--template') && idx + 1 < len(extra_args)
            return extra_args[idx + 1]
        endif
    endfor
    return ''
enddef

export def ResolveTemplatePath(repo_root: string, extra_args: list<string> = []): string
    var cli_path = ExtractTemplatePath(extra_args)
    if cli_path != ''
        var expanded = expand(cli_path)
        if filereadable(expanded)
            return expanded
        elseif filereadable(repo_root .. '/' .. cli_path)
            return repo_root .. '/' .. cli_path
        endif
        return expanded
    endif

    var config_path = trim(system('git -C ' .. fnameescape(repo_root) .. ' config --path --get commit.template'))
    if v:shell_error == 0 && config_path != ''
        var expanded = expand(config_path)
        if filereadable(expanded)
            return expanded
        elseif filereadable(repo_root .. '/' .. config_path)
            return repo_root .. '/' .. config_path
        endif
        return expanded
    endif

    return ''
enddef

export def ResolveCommentChar(repo_root: string): string
    var ch = trim(system('git -C ' .. fnameescape(repo_root) .. ' config --get core.commentChar'))
    if v:shell_error == 0 && ch != '' && ch != 'auto'
        return ch
    endif
    return '#'
enddef

export def BuildCommitTemplate(repo_root: string, extra_args: list<string> = []): list<string>
    var lines: list<string> = []
    var is_amend: bool = index(extra_args, '--amend') >= 0
    var c: string = ResolveCommentChar(repo_root)
    var source: string = ''
    var sha: string = ''

    if is_amend
        source = 'commit'
        sha = trim(system('git -C ' .. fnameescape(repo_root) .. ' rev-parse HEAD'))
        var prev_msg: string = trim(system('git -C ' .. fnameescape(repo_root) .. ' log -n 1 --format=%B HEAD'))
        if v:shell_error == 0 && prev_msg != ''
            lines = split(prev_msg, "\n")
        endif
        add(lines, '')
    else
        var merge_msg_path = trim(system('git -C ' .. fnameescape(repo_root) .. ' rev-parse --git-path MERGE_MSG'))
        if !filereadable(merge_msg_path)
            merge_msg_path = repo_root .. '/' .. merge_msg_path
        endif
        var squash_msg_path = trim(system('git -C ' .. fnameescape(repo_root) .. ' rev-parse --git-path SQUASH_MSG'))
        if !filereadable(squash_msg_path)
            squash_msg_path = repo_root .. '/' .. squash_msg_path
        endif

        if filereadable(merge_msg_path)
            source = 'merge'
            lines = readfile(merge_msg_path)
            add(lines, '')
        elseif filereadable(squash_msg_path)
            source = 'squash'
            lines = readfile(squash_msg_path)
            add(lines, '')
        else
            var tmpl_path = ResolveTemplatePath(repo_root, extra_args)
            if tmpl_path != '' && filereadable(tmpl_path)
                source = 'template'
                lines = readfile(tmpl_path)
            else
                lines = ['', '']
            endif
        endif
    endif

    # Run prepare-commit-msg hook if available
    var hook_path = trim(system('git -C ' .. fnameescape(repo_root) .. ' rev-parse --git-path hooks/prepare-commit-msg'))
    if v:shell_error == 0 && hook_path != ''
        if !filereadable(hook_path)
            hook_path = repo_root .. '/' .. hook_path
        endif
        if filereadable(hook_path) && getfperm(hook_path) =~# 'x'
            var tmp_hook_file = tempname()
            writefile(lines, tmp_hook_file)
            var hook_cmd = fnameescape(hook_path) .. ' ' .. fnameescape(tmp_hook_file)
            if source != ''
                hook_cmd ..= ' ' .. fnameescape(source)
                if sha != ''
                    hook_cmd ..= ' ' .. fnameescape(sha)
                endif
            endif
            system(hook_cmd)
            if filereadable(tmp_hook_file)
                lines = readfile(tmp_hook_file)
            endif
            delete(tmp_hook_file)
        endif
    endif

    add(lines, printf('%s Please enter the commit message for your changes. Lines starting', c))
    add(lines, printf('%s with ''%s'' will be ignored, and an empty message aborts the commit.', c, c))
    add(lines, c)

    var status_out: string = system('git -C ' .. fnameescape(repo_root) .. ' status')
    if v:shell_error == 0 && status_out != ''
        for line in split(status_out, "\n")
            add(lines, line == '' ? c : c .. ' ' .. line)
        endfor
    endif

    var is_verbose = index(extra_args, '-v') >= 0 || index(extra_args, '--verbose') >= 0
    if !is_verbose
        var cfg_verbose = trim(system('git -C ' .. fnameescape(repo_root) .. ' config --bool --get commit.verbose'))
        if cfg_verbose == 'true'
            is_verbose = true
        endif
    endif

    if is_verbose
        add(lines, c .. ' ------------------------ >8 ------------------------')
        add(lines, c .. ' Do not modify or remove the line above.')
        add(lines, c .. ' Everything below it will be ignored.')
        var diff_cmd = is_amend ? 'git -C ' .. fnameescape(repo_root) .. ' diff HEAD^ HEAD' : 'git -C ' .. fnameescape(repo_root) .. ' diff --cached'
        var diff_out = system(diff_cmd)
        if v:shell_error == 0 && diff_out != ''
            extend(lines, split(diff_out, "\n"))
        endif
    endif

    return lines
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    if arg_lead == ''
        return copy(completion_candidates)
    endif
    return filter(copy(completion_candidates), (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
