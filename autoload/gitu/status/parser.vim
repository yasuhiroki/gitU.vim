vim9script

export def ParsePorcelain(lines: list<string>): dict<any>
    var result: dict<any> = {
        branch: '',
        staged: [],
        unstaged: [],
        untracked: [],
    }

    for line in lines
        if line =~ '^## '
            result.branch = line[3 :]
            continue
        endif

        if len(line) < 4
            continue
        endif

        var index_status: string = line[0]
        var worktree_status: string = line[1]
        var filepath: string = line[3 :]

        if index_status == '?' && worktree_status == '?'
            add(result.untracked, { status: '?', file: filepath })
            continue
        endif

        if index_status != ' ' && index_status != '?'
            var staged_file: string = filepath
            if (index_status == 'R' || index_status == 'C') && filepath =~ ' -> '
                var parts: list<string> = split(filepath, ' -> ')
                if len(parts) >= 2
                    staged_file = parts[1]
                endif
            endif
            add(result.staged, { status: index_status, file: staged_file, raw_file: filepath })
        endif

        if worktree_status != ' ' && worktree_status != '?'
            add(result.unstaged, { status: worktree_status, file: filepath })
        endif
    endfor

    return result
enddef

export def RenderStatus(parsed: dict<any>): dict<any>
    var lines: list<string> = []
    var line_map: dict<dict<any>> = {}

    if parsed.branch != ''
        add(lines, 'Branch: ' .. parsed.branch)
        add(lines, '')
    endif

    var has_changes: bool = false

    if len(parsed.staged) > 0
        has_changes = true
        add(lines, 'Changes to be committed:')
        for item in parsed.staged
            var disp_file: string = get(item, 'raw_file', item.file)
            add(lines, printf('  %s  %s', item.status, disp_file))
            line_map[string(len(lines))] = {
                section: 'staged',
                status: item.status,
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if len(parsed.unstaged) > 0
        has_changes = true
        add(lines, 'Changes not staged for commit:')
        for item in parsed.unstaged
            add(lines, printf('  %s  %s', item.status, item.file))
            line_map[string(len(lines))] = {
                section: 'unstaged',
                status: item.status,
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if len(parsed.untracked) > 0
        has_changes = true
        add(lines, 'Untracked files:')
        for item in parsed.untracked
            add(lines, printf('  ?  %s', item.file))
            line_map[string(len(lines))] = {
                section: 'untracked',
                status: '?',
                file: item.file,
            }
        endfor
        add(lines, '')
    endif

    if !has_changes
        add(lines, 'nothing to commit, working tree clean')
    endif

    return { lines: lines, line_map: line_map }
enddef

export def BuildDiffArgs(section: string, file_path: string): list<string>
    if section == 'staged'
        return ['diff', '--cached', '--', file_path]
    elseif section == 'untracked'
        return ['diff', '--no-index', '--', '/dev/null', file_path]
    endif
    return ['diff', '--', file_path]
enddef

export def ParseNumstat(lines: list<string>): dict<dict<any>>
    var stats: dict<dict<any>> = {}
    for line in lines
        if line == ''
            continue
        endif
        var parts = split(line, "\t")
        if len(parts) < 3
            continue
        endif
        var is_binary = (parts[0] == '-' || parts[1] == '-')
        var added = is_binary ? 0 : str2nr(parts[0])
        var deleted = is_binary ? 0 : str2nr(parts[1])
        var raw_path = parts[2]
        var file_path = raw_path
        if raw_path =~ ' => '
            var rename_matches = matchlist(raw_path, '\v^(.*)\{[^{}]* \=\> ([^{}]*)\}(.*)$')
            if len(rename_matches) >= 4
                file_path = rename_matches[1] .. rename_matches[2] .. rename_matches[3]
            else
                var arrow_parts = split(raw_path, ' => ')
                if len(arrow_parts) >= 2
                    file_path = arrow_parts[-1]
                endif
            endif
        endif
        stats[file_path] = {
            added: added,
            deleted: deleted,
            total: added + deleted,
            is_binary: is_binary,
        }
    endfor
    return stats
enddef

export def GetSelectedFiles(state: dict<any>, start_lnum: number, end_lnum: number, action: string): list<string>
    if start_lnum <= 0 || end_lnum <= 0
        return []
    endif
    var first_line: number = min([start_lnum, end_lnum])
    var last_line: number = max([start_lnum, end_lnum])
    var files: list<string> = []

    for lnum in range(first_line, last_line)
        var entry: dict<any> = get(state.line_map, string(lnum), {})
        if empty(entry) || get(entry, 'file', '') == ''
            continue
        endif
        var is_match: bool = (action == 'stage' && entry.section != 'staged')
            || (action == 'unstage' && entry.section == 'staged')
        if is_match && index(files, entry.file) < 0
            add(files, entry.file)
        endif
    endfor

    return files
enddef
