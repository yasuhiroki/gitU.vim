vim9script

export def ExtractCommitHash(line: string): string
    return matchstr(line, '^[*|/\\_. -]*\*[ |/\\_. -]*\zs\x\{7,40\}\ze\>')
enddef

export def ExtractSpecialRef(line: string): dict<any>
    if line =~# '\[Unstaged changes\]'
        return { type: 'unstaged' }
    endif
    if line =~# '\[Staged changes\]'
        return { type: 'staged' }
    endif
    var m = matchlist(line, '\[\(stash@{\d\+}\)\]\%(\s\+\(\x\+\)\)\?')
    if len(m) >= 2 && m[1] != ''
        return { type: 'stash', ref: m[1], hash: get(m, 2, '') }
    endif
    return {}
enddef

export def ParseStatusPrelude(status_lines: list<string>): list<string>
    var has_staged = false
    var has_unstaged = false

    for line in status_lines
        if len(line) < 2
            continue
        endif
        var x = line[0]
        var y = line[1]
        if x =~# '[MADRC]'
            has_staged = true
        endif
        if y =~# '[MD]' || x == 'U' || y == 'U'
            has_unstaged = true
        endif
    endfor

    var res: list<string> = []
    if has_unstaged
        add(res, '* [Unstaged changes]')
    endif
    if has_staged
        add(res, '* [Staged changes]')
    endif
    return res
enddef

export def ParseStashPrelude(stash_lines: list<string>): list<string>
    var res: list<string> = []
    for idx in range(len(stash_lines))
        var line = trim(stash_lines[idx])
        if line == ''
            continue
        endif
        var m = matchlist(line, '^\(stash@{\d\+}\)\s\+\(\x\+\)\s\+\(.\+\)$')
        if len(m) >= 4
            add(res, printf('* [%s] %s %s', m[1], m[2], m[3]))
            continue
        endif
        var m2 = matchlist(line, '^\(\x\+\)\s\+\(.\+\)$')
        if len(m2) >= 3
            var stash_ref = printf('stash@{%d}', idx)
            add(res, printf('* [%s] %s %s', stash_ref, m2[1], m2[2]))
            continue
        endif
        add(res, '* [' .. line .. ']')
    endfor
    return res
enddef

export def ExtractFilePath(line: string): string
    var renamed: string = matchstr(line, '^[RC]\d*\t[^\t]\+\t\zs.\+$')
    if renamed != ''
        return renamed
    endif
    return matchstr(line, '^[MADTU]\t\zs.\+$')
enddef

export def StripTrailingWhitespace(lines: list<string>): list<string>
    return mapnew(lines, (_, line: string): string => substitute(line, '\s\+$', '', ''))
enddef

export def FormatCommitDetail(lines: list<string>): list<string>
    var out_lines = copy(lines)
    var files_idx: number = index(out_lines, '--- Files ---')
    if files_idx < 0
        return out_lines
    endif

    while files_idx > 0 && out_lines[files_idx - 1] =~ '^\s*$'
        remove(out_lines, files_idx - 1)
        files_idx -= 1
    endwhile

    insert(out_lines, '', files_idx)
    return out_lines
enddef

export def NormalizeArgs(raw_args: list<string>): list<string>
    var result: list<string> = []
    var patterns: list<string> = []
    var skip_next = false

    for i in range(len(raw_args))
        if skip_next
            skip_next = false
            continue
        endif

        var arg = raw_args[i]
        if arg == '-n' || arg == '-L' || arg == '-S' || arg == '-G'
            add(result, arg)
            if i + 1 < len(raw_args)
                add(result, raw_args[i + 1])
                skip_next = true
            endif
        elseif arg =~ '^--%(since|after|until|before|max-count|skip|grep|author|committer)='
            add(result, arg)
        elseif arg == '--since' || arg == '--after' || arg == '--until' || arg == '--before' || arg == '--max-count' || arg == '--skip' || arg == '--grep' || arg == '--author' || arg == '--committer'
            add(result, arg)
            if i + 1 < len(raw_args)
                add(result, raw_args[i + 1])
                skip_next = true
            endif
        elseif arg =~ '^-'
            add(result, arg)
        else
            add(patterns, arg)
        endif
    endfor

    var has_diff_filter = false
    for item in result
        if item == '-G' || item =~ '^-G' || item == '-S' || item =~ '^-S'
            has_diff_filter = true
            break
        endif
    endfor

    if !has_diff_filter && !empty(patterns)
        var combined_pattern = join(patterns, ' ')
        add(result, '-G' .. combined_pattern)
    endif

    return result
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var candidates: list<string> = [
        '--all',
        '--branches',
        '--tags',
        '--remotes',
        '--first-parent',
        '--merges',
        '--no-merges',
        '-n',
        '-G',
        '-S',
    ]
    if arg_lead == ''
        return candidates
    endif
    return filter(candidates, (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef
