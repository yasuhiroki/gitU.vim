vim9script

export def ToStr(val: any, default_val: string = ''): string
    if type(val) == v:t_string
        return val
    elseif type(val) == v:t_number
        return string(val)
    endif
    return default_val
enddef

export def NormalizeArgs(raw_args: list<string>): dict<any>
    var mode: string = 'list'
    var target: string = ''
    var extra_args: list<string> = []
    var repo: string = ''
    var owner: string = ''

    var idx: number = 0
    if len(raw_args) > 0
        var first = raw_args[0]
        if first == 'list' || first == 'ls'
            mode = 'list'
            idx = 1
        elseif first == 'show' || first == 'view'
            mode = 'show'
            idx = 1
            if len(raw_args) > 1 && raw_args[1] !~ '^-'
                target = substitute(raw_args[1], '^#', '', '')
                idx = 2
            endif
        elseif first =~ '^#\?\d\+$'
            mode = 'show'
            target = substitute(first, '^#', '', '')
            idx = 1
        endif
    endif

    while idx < len(raw_args)
        var arg = raw_args[idx]
        if (arg == '-R' || arg == '--repo') && idx + 1 < len(raw_args)
            repo = raw_args[idx + 1]
            add(extra_args, arg)
            add(extra_args, repo)
            idx += 2
            continue
        elseif arg =~ '^--repo='
            repo = substitute(arg, '^--repo=', '', '')
            add(extra_args, arg)
            idx += 1
            continue
        elseif arg == '--owner' && idx + 1 < len(raw_args)
            owner = raw_args[idx + 1]
            add(extra_args, arg)
            add(extra_args, owner)
            idx += 2
            continue
        elseif arg =~ '^--owner='
            owner = substitute(arg, '^--owner=', '', '')
            add(extra_args, arg)
            idx += 1
            continue
        endif
        add(extra_args, arg)
        idx += 1
    endwhile

    return {
        mode: mode,
        target: target,
        extra_args: extra_args,
        repo: repo,
        owner: owner,
    }
enddef

def SafeJsonDecode(lines: list<string>, fallback: any): any
    var raw = trim(join(lines, "\n"))
    if raw == ''
        return fallback
    endif
    try
        var decoded = json_decode(raw)
        return decoded == v:null ? fallback : decoded
    catch
        return fallback
    endtry
enddef

export def FormatDate(iso_str: any): string
    if type(iso_str) != v:t_string || iso_str == ''
        return '-'
    endif
    var matches = matchlist(iso_str, '\v^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})')
    if len(matches) >= 3 && matches[1] != ''
        return matches[1] .. ' ' .. matches[2]
    endif
    return iso_str
enddef

export def FormatAuthor(author_val: any): string
    if type(author_val) == v:t_dict
        var login = ToStr(get(author_val, 'login', ''))
        return login != '' ? '@' .. login : '-'
    elseif type(author_val) == v:t_string && author_val != ''
        return author_val =~ '^@' ? author_val : '@' .. author_val
    endif
    return '-'
enddef

export def FormatLabels(labels_val: any): list<string>
    var result: list<string> = []
    if type(labels_val) != v:t_list
        return result
    endif
    for item in labels_val
        if type(item) == v:t_dict
            var name = ToStr(get(item, 'name', ''))
            if name != ''
                add(result, name)
            endif
        elseif type(item) == v:t_string && item != ''
            add(result, item)
        endif
    endfor
    return result
enddef

export def FormatAssignees(assignees_val: any): list<string>
    var result: list<string> = []
    if type(assignees_val) != v:t_list
        return result
    endif
    for item in assignees_val
        if type(item) == v:t_dict
            var login = ToStr(get(item, 'login', ''))
            if login != ''
                add(result, '@' .. login)
            endif
        elseif type(item) == v:t_string && item != ''
            add(result, item =~ '^@' ? item : '@' .. item)
        endif
    endfor
    return result
enddef

def SplitBody(body_val: any): list<string>
    if type(body_val) != v:t_string || trim(body_val) == ''
        return ['(No description provided)']
    endif
    var cleaned = substitute(body_val, "\r", '', 'g')
    return split(cleaned, "\n", 1)
enddef

def RenderComments(comments_val: any): list<string>
    if type(comments_val) != v:t_list || empty(comments_val)
        return []
    endif
    var lines: list<string> = ['', printf('--- Comments (%d) ---', len(comments_val))]
    for comment in comments_val
        if type(comment) != v:t_dict
            continue
        endif
        var author = FormatAuthor(get(comment, 'author', {}))
        var created = FormatDate(get(comment, 'createdAt', ''))
        add(lines, printf('%s (%s):', author, created))
        var body_lines = SplitBody(get(comment, 'body', ''))
        for bline in body_lines
            add(lines, '  ' .. bline)
        endfor
        add(lines, '')
    endfor
    return lines
enddef

export def ParseIssueList(lines: list<string>): list<dict<any>>
    var data = SafeJsonDecode(lines, [])
    return type(data) == v:t_list ? data : []
enddef

export def RenderIssueList(issues: list<dict<any>>): dict<any>
    if empty(issues)
        return {
            lines: ['(No issues found)'],
            line_map: {},
        }
    endif

    var out_lines: list<string> = []
    var line_map: dict<dict<any>> = {}
    var lnum: number = 1

    for issue in issues
        var num = get(issue, 'number', 0)
        var num_str = '#' .. ToStr(num, '0')
        var state_raw = toupper(ToStr(get(issue, 'state', 'OPEN'), 'OPEN'))
        var state_str = '[' .. state_raw .. ']'
        var title = ToStr(get(issue, 'title', ''))
        var author = FormatAuthor(get(issue, 'author', {}))
        var labels = FormatLabels(get(issue, 'labels', []))
        var label_str = empty(labels) ? '' : ' [' .. join(labels, ', ') .. ']'

        var line = printf('%-6s %-8s %s%s (%s)', num_str, state_str, title, label_str, author)
        add(out_lines, line)
        line_map[string(lnum)] = issue
        lnum += 1
    endfor

    return {
        lines: out_lines,
        line_map: line_map,
    }
enddef

export def ParseIssueDetail(lines: list<string>): dict<any>
    var data = SafeJsonDecode(lines, {})
    return type(data) == v:t_dict ? data : {}
enddef

export def RenderIssueDetail(issue: dict<any>): list<string>
    if empty(issue)
        return ['(No issue details available)']
    endif

    var num = get(issue, 'number', 0)
    var state_raw = toupper(ToStr(get(issue, 'state', 'OPEN'), 'OPEN'))
    var title = ToStr(get(issue, 'title', ''))
    var author = FormatAuthor(get(issue, 'author', {}))
    var assignees = FormatAssignees(get(issue, 'assignees', []))
    var labels = FormatLabels(get(issue, 'labels', []))
    var milestone_val = get(issue, 'milestone', {})
    var milestone_title = type(milestone_val) == v:t_dict ? ToStr(get(milestone_val, 'title', '')) : ''
    var created = FormatDate(get(issue, 'createdAt', ''))
    var updated = FormatDate(get(issue, 'updatedAt', ''))
    var url = ToStr(get(issue, 'url', ''))

    var out: list<string> = [
        printf('Issue:     #%d [%s]', num, state_raw),
        printf('Title:     %s', title),
        printf('Author:    %s', author),
        printf('Assignees: %s', empty(assignees) ? '-' : join(assignees, ', ')),
        printf('Labels:    %s', empty(labels) ? '-' : join(labels, ', ')),
    ]
    if milestone_title != ''
        add(out, printf('Milestone: %s', milestone_title))
    endif
    extend(out, [
        printf('Created:   %s', created),
        printf('Updated:   %s', updated),
    ])
    if url != ''
        add(out, printf('URL:       %s', url))
    endif

    add(out, '')
    add(out, '--- Description ---')
    extend(out, SplitBody(get(issue, 'body', '')))
    extend(out, RenderComments(get(issue, 'comments', [])))

    return out
enddef

export def ParsePrList(lines: list<string>): list<dict<any>>
    var data = SafeJsonDecode(lines, [])
    return type(data) == v:t_list ? data : []
enddef

def FormatPrState(pr: dict<any>): string
    var is_draft = get(pr, 'isDraft', false)
    var state_raw = toupper(ToStr(get(pr, 'state', 'OPEN'), 'OPEN'))
    if is_draft && state_raw == 'OPEN'
        return '[DRAFT]'
    endif
    return '[' .. state_raw .. ']'
enddef

export def RenderPrList(prs: list<dict<any>>): dict<any>
    if empty(prs)
        return {
            lines: ['(No pull requests found)'],
            line_map: {},
        }
    endif

    var out_lines: list<string> = []
    var line_map: dict<dict<any>> = {}
    var lnum: number = 1

    for pr in prs
        var num = get(pr, 'number', 0)
        var num_str = '#' .. ToStr(num, '0')
        var state_str = FormatPrState(pr)
        var title = ToStr(get(pr, 'title', ''))
        var base = ToStr(get(pr, 'baseRefName', ''))
        var head = ToStr(get(pr, 'headRefName', ''))
        var branch_str = (base != '' && head != '') ? printf(' (%s <- %s)', base, head) : ''
        var author = FormatAuthor(get(pr, 'author', {}))
        var labels = FormatLabels(get(pr, 'labels', []))
        var label_str = empty(labels) ? '' : ' [' .. join(labels, ', ') .. ']'

        var line = printf('%-6s %-8s %s%s%s (%s)', num_str, state_str, title, branch_str, label_str, author)
        add(out_lines, line)
        line_map[string(lnum)] = pr
        lnum += 1
    endfor

    return {
        lines: out_lines,
        line_map: line_map,
    }
enddef

export def ParsePrDetail(lines: list<string>): dict<any>
    var data = SafeJsonDecode(lines, {})
    return type(data) == v:t_dict ? data : {}
enddef

export def RenderPrDetail(pr: dict<any>): dict<any>
    if empty(pr)
        return {
            lines: ['(No pull request details available)'],
            file_map: {},
        }
    endif

    var num = get(pr, 'number', 0)
    var state_str = FormatPrState(pr)
    var additions = get(pr, 'additions', 0)
    var deletions = get(pr, 'deletions', 0)
    var changed_files = get(pr, 'changedFiles', 0)
    var stats_str = (additions > 0 || deletions > 0 || changed_files > 0)
        ? printf(' (+%d / -%d in %d files)', additions, deletions, changed_files)
        : ''

    var title = ToStr(get(pr, 'title', ''))
    var author = FormatAuthor(get(pr, 'author', {}))
    var base = ToStr(get(pr, 'baseRefName', ''))
    var head = ToStr(get(pr, 'headRefName', ''))
    var review = ToStr(get(pr, 'reviewDecision', ''))
    var assignees = FormatAssignees(get(pr, 'assignees', []))
    var labels = FormatLabels(get(pr, 'labels', []))
    var created = FormatDate(get(pr, 'createdAt', ''))
    var updated = FormatDate(get(pr, 'updatedAt', ''))
    var url = ToStr(get(pr, 'url', ''))

    var out: list<string> = [
        printf('PR:        #%d %s%s', num, state_str, stats_str),
        printf('Title:     %s', title),
        printf('Author:    %s', author),
    ]
    if base != '' || head != ''
        add(out, printf('Branch:    %s <- %s', base, head))
    endif
    if review != ''
        add(out, printf('Review:    %s', review))
    endif
    extend(out, [
        printf('Assignees: %s', empty(assignees) ? '-' : join(assignees, ', ')),
        printf('Labels:    %s', empty(labels) ? '-' : join(labels, ', ')),
        printf('Created:   %s', created),
        printf('Updated:   %s', updated),
    ])
    if url != ''
        add(out, printf('URL:       %s', url))
    endif

    add(out, '')
    add(out, '--- Description ---')
    extend(out, SplitBody(get(pr, 'body', '')))
    extend(out, RenderComments(get(pr, 'comments', [])))

    var file_map: dict<string> = {}
    var files_val = get(pr, 'files', [])
    if type(files_val) == v:t_list && !empty(files_val)
        add(out, '')
        add(out, '--- Files ---')
        for f in files_val
            if type(f) != v:t_dict
                continue
            endif
            var path = ToStr(get(f, 'path', ''))
            if path == ''
                continue
            endif
            var f_add = get(f, 'additions', 0)
            var f_del = get(f, 'deletions', 0)
            add(out, printf('M	%s (+%d/-%d)', path, f_add, f_del))
            file_map[string(len(out))] = path
        endfor
    endif

    return {
        lines: out,
        file_map: file_map,
    }
enddef

export def FilterDiffByFile(diff_lines: list<string>, file_path: string): list<string>
    if file_path == '' || empty(diff_lines)
        return diff_lines
    endif

    var filtered: list<string> = []
    var matching: bool = false
    var suffix = ' b/' .. file_path

    for line in diff_lines
        if line =~ '^diff --git '
            if stridx(line, suffix) >= 0 || line =~ '\V' .. escape(file_path, '\') .. '\$'
                matching = true
            else
                matching = false
            endif
        endif
        if matching
            add(filtered, line)
        endif
    endfor

    return empty(filtered) ? ['(No diff found for ' .. file_path .. ')'] : filtered
enddef

export def ParseProjectList(lines: list<string>): list<dict<any>>
    var data = SafeJsonDecode(lines, {})
    if type(data) == v:t_dict && has_key(data, 'projects') && type(data.projects) == v:t_list
        return data.projects
    elseif type(data) == v:t_list
        return data
    endif
    return []
enddef

export def RenderProjectList(projects: list<dict<any>>): dict<any>
    if empty(projects)
        return {
            lines: ['(No projects found)'],
            line_map: {},
        }
    endif

    var out_lines: list<string> = []
    var line_map: dict<dict<any>> = {}
    var lnum: number = 1

    for proj in projects
        var num = get(proj, 'number', 0)
        var num_str = '#' .. ToStr(num, '0')
        var closed = get(proj, 'closed', false)
        var state_str = closed ? '[CLOSED]' : '[OPEN]'
        var title = ToStr(get(proj, 'title', ''))
        var items_val = get(proj, 'items', {})
        var item_count = type(items_val) == v:t_dict ? get(items_val, 'totalCount', 0) : 0
        var owner_val = get(proj, 'owner', {})
        var owner_login = type(owner_val) == v:t_dict ? ToStr(get(owner_val, 'login', '')) : ''
        var owner_str = owner_login != '' ? ' (@' .. owner_login .. ')' : ''

        var line = printf('%-6s %-8s %s (%d items)%s', num_str, state_str, title, item_count, owner_str)
        add(out_lines, line)
        line_map[string(lnum)] = proj
        lnum += 1
    endfor

    return {
        lines: out_lines,
        line_map: line_map,
    }
enddef

export def ParseProjectDetail(lines: list<string>): dict<any>
    var data = SafeJsonDecode(lines, {})
    return type(data) == v:t_dict ? data : {}
enddef

export def ParseProjectItems(lines: list<string>): list<dict<any>>
    var data = SafeJsonDecode(lines, {})
    if type(data) == v:t_dict && has_key(data, 'items') && type(data.items) == v:t_list
        return data.items
    elseif type(data) == v:t_list
        return data
    endif
    return []
enddef

export def RenderProjectDetail(proj: dict<any>, items: list<dict<any>>): dict<any>
    if empty(proj) && empty(items)
        return {
            lines: ['(No project details available)'],
            item_map: {},
        }
    endif

    var num = get(proj, 'number', 0)
    var closed = get(proj, 'closed', false)
    var state_str = closed ? '[CLOSED]' : '[OPEN]'
    var title = ToStr(get(proj, 'title', ''))
    var owner_val = get(proj, 'owner', {})
    var owner_login = type(owner_val) == v:t_dict ? ToStr(get(owner_val, 'login', '')) : ''
    var items_val = get(proj, 'items', {})
    var total_count = type(items_val) == v:t_dict ? get(items_val, 'totalCount', len(items)) : len(items)
    var short_desc = ToStr(get(proj, 'shortDescription', ''))
    var url = ToStr(get(proj, 'url', ''))
    var readme = ToStr(get(proj, 'readme', ''))

    var out: list<string> = [
        printf('Project:     #%d %s', num, state_str),
        printf('Title:       %s', title),
    ]
    if owner_login != ''
        add(out, printf('Owner:       @%s', owner_login))
    endif
    add(out, printf('Items:       %d', total_count))
    if short_desc != ''
        add(out, printf('Description: %s', short_desc))
    endif
    if url != ''
        add(out, printf('URL:         %s', url))
    endif

    if trim(readme) != ''
        add(out, '')
        add(out, '--- Readme ---')
        extend(out, SplitBody(readme))
    endif

    var item_map: dict<dict<any>> = {}
    add(out, '')
    add(out, printf('--- Items (%d) ---', len(items)))
    if empty(items)
        add(out, '  (No items in project)')
    else
        for item in items
            if type(item) != v:t_dict
                continue
            endif
            var status = ToStr(get(item, 'status', '-'), '-')
            var content = get(item, 'content', {})
            var item_type = type(content) == v:t_dict ? ToStr(get(content, 'type', 'Item'), 'Item') : 'Item'
            var c_num = type(content) == v:t_dict ? get(content, 'number', 0) : 0
            var num_str = c_num > 0 ? '#' .. ToStr(c_num) .. ' ' : ''
            var item_title = ToStr(get(item, 'title', type(content) == v:t_dict ? get(content, 'title', '') : ''))
            var assignees = FormatAssignees(get(item, 'assignees', []))
            var assign_str = empty(assignees) ? '' : ' (' .. join(assignees, ', ') .. ')'

            add(out, printf('  [%s] %s(%s) %s%s', status, num_str, item_type, item_title, assign_str))
            item_map[string(len(out))] = item
        endfor
    endif

    return {
        lines: out,
        item_map: item_map,
    }
enddef

export def RenderProjectItemDetail(item: dict<any>): list<string>
    if empty(item)
        return ['(Select an item under --- Items --- to view details)']
    endif

    var content = get(item, 'content', {})
    if type(content) != v:t_dict
        content = {}
    endif

    var title = ToStr(get(item, 'title', get(content, 'title', '')))
    var status = ToStr(get(item, 'status', '-'), '-')
    var item_type = ToStr(get(content, 'type', get(item, 'type', 'Item')), 'Item')
    var c_num = get(content, 'number', 0)
    var repo = ToStr(get(content, 'repository', ''))
    var url = ToStr(get(content, 'url', ''))
    var assignees = FormatAssignees(get(item, 'assignees', []))
    var labels = FormatLabels(get(item, 'labels', []))
    var body = get(content, 'body', '')

    var out: list<string> = [
        printf('Item:       %s%s', c_num > 0 ? '#' .. ToStr(c_num) .. ' ' : '', title),
        printf('Type:       %s', item_type),
        printf('Status:     %s', status),
    ]
    if repo != ''
        add(out, printf('Repository: %s', repo))
    endif
    extend(out, [
        printf('Assignees:  %s', empty(assignees) ? '-' : join(assignees, ', ')),
        printf('Labels:     %s', empty(labels) ? '-' : join(labels, ', ')),
    ])
    if url != ''
        add(out, printf('URL:        %s', url))
    endif

    add(out, '')
    add(out, '--- Description ---')
    extend(out, SplitBody(body))

    return out
enddef
