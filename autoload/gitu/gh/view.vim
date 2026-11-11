vim9script

import autoload 'gitu/core/buffer.vim'
import autoload 'gitu/core/gh.vim'
import autoload 'gitu/core/git.vim'
import autoload 'gitu/core/notify.vim'
import autoload 'gitu/core/view.vim'
import autoload 'gitu/gh/parser.vim'
import autoload 'gitu/log/github.vim'

var next_view_id: number = 0
var views: dict<dict<any>> = {}

var issue_completions: list<string> = [
    'list',
    'show',
    'view',
    '--state',
    '--assignee',
    '--author',
    '--label',
    '--limit',
    '--milestone',
    '--search',
    '--repo',
]

var pr_completions: list<string> = [
    'list',
    'show',
    'view',
    '--state',
    '--assignee',
    '--author',
    '--base',
    '--head',
    '--draft',
    '--label',
    '--limit',
    '--search',
    '--repo',
]

var project_completions: list<string> = [
    'list',
    'show',
    'view',
    '--owner',
    '--closed',
    '--limit',
]

var gh_subcommands: list<string> = [
    'issue',
    'pr',
    'project',
]

def FilterPrefix(candidates: list<string>, arg_lead: string): list<string>
    if arg_lead == ''
        return copy(candidates)
    endif
    return filter(copy(candidates), (_, val: string): bool => stridx(val, arg_lead) == 0)
enddef

export def CompleteIssue(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return FilterPrefix(issue_completions, arg_lead)
enddef

export def CompletePr(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return FilterPrefix(pr_completions, arg_lead)
enddef

export def CompleteProject(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    return FilterPrefix(project_completions, arg_lead)
enddef

export def CompleteGh(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
    var before_cursor = cmd_line[0 : cursor_pos - 1]
    var parts = split(before_cursor, '\s\+', 1)
    if len(parts) <= 2
        return FilterPrefix(gh_subcommands, arg_lead)
    endif
    var sub = parts[1]
    if sub == 'issue'
        return CompleteIssue(arg_lead, cmd_line, cursor_pos)
    elseif sub == 'pr'
        return CompletePr(arg_lead, cmd_line, cursor_pos)
    elseif sub == 'project'
        return CompleteProject(arg_lead, cmd_line, cursor_pos)
    endif
    return []
enddef

def HasLimitArg(args: list<string>): bool
    for arg in args
        if arg == '-L' || arg =~ '^--limit'
            return true
        endif
    endfor
    return false
enddef

def RepoFlags(state: dict<any>): list<string>
    if state.repo != ''
        return ['-R', state.repo]
    endif
    return []
enddef

def OwnerFlags(state: dict<any>, override_owner: string = ''): list<string>
    var owner = override_owner != '' ? override_owner : state.owner
    if owner != ''
        return ['--owner', owner]
    endif
    return []
enddef

def LoadIssueDetail(view_id: number, num_str: string)
    var key = view.GetKey(view_id)
    if !has_key(views, key) || num_str == ''
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'issue',
        'view',
        num_str,
        '--json',
        'number,title,state,stateReason,author,labels,assignees,milestone,createdAt,updatedAt,url,body,comments',
    ] + RepoFlags(state)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_detail_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load issue #' .. num_str] : res.stderr
                buffer.SetLines(cur.detail_bufnr, err)
                return
            endif
            var detail = parser.ParseIssueDetail(res.stdout)
            var url = parser.ToStr(get(detail, 'url', ''))
            if url != ''
                cur.current_url = url
            endif
            buffer.SetLines(cur.detail_bufnr, parser.RenderIssueDetail(detail))
            buffer.ResetWindowTop(cur.detail_winid)
        },
    })
enddef

def LoadIssueList(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'issue',
        'list',
        '--json',
        'number,title,state,author,labels,assignees,updatedAt,url',
    ]
    if !HasLimitArg(state.extra_args)
        extend(args, ['--limit', '50'])
    endif
    extend(args, state.extra_args)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_list_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load issues.'] : res.stderr
                buffer.SetLines(cur.list_bufnr, err)
                if cur.target == ''
                    buffer.SetLines(cur.detail_bufnr, err)
                endif
                return
            endif

            var issues = parser.ParseIssueList(res.stdout)
            var rendered = parser.RenderIssueList(issues)
            cur.line_map = rendered.line_map
            buffer.SetLines(cur.list_bufnr, rendered.lines)

            var target_lnum: number = 1
            var desired_num = cur.target != '' ? cur.target : cur.current_number
            if desired_num != ''
                for [l_str, ent] in items(cur.line_map)
                    if parser.ToStr(get(ent, 'number', '')) == desired_num
                        target_lnum = str2nr(l_str)
                        break
                    endif
                endfor
            endif

            if cur.list_winid > 0 && win_id2win(cur.list_winid) > 0
                win_execute(cur.list_winid, printf('normal! %dG0', target_lnum))
            endif

            if cur.target != '' && desired_num == cur.target
                cur.current_number = cur.target
                LoadIssueDetail(view_id, cur.target)
            elseif has_key(cur.line_map, string(target_lnum))
                var ent = cur.line_map[string(target_lnum)]
                var num_str = parser.ToStr(get(ent, 'number', ''))
                cur.current_number = num_str
                cur.current_url = parser.ToStr(get(ent, 'url', ''))
                LoadIssueDetail(view_id, num_str)
            else
                buffer.SetLines(cur.detail_bufnr, ['(No issue selected)'])
            endif
        },
    })
enddef

def LoadPrDetail(view_id: number, num_str: string)
    var key = view.GetKey(view_id)
    if !has_key(views, key) || num_str == ''
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'pr',
        'view',
        num_str,
        '--json',
        'number,title,state,isDraft,author,baseRefName,headRefName,assignees,labels,reviewDecision,additions,deletions,changedFiles,createdAt,updatedAt,url,body,comments,files',
    ] + RepoFlags(state)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_detail_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load PR #' .. num_str] : res.stderr
                buffer.SetLines(cur.detail_bufnr, err)
                return
            endif
            var detail = parser.ParsePrDetail(res.stdout)
            var url = parser.ToStr(get(detail, 'url', ''))
            if url != ''
                cur.current_url = url
            endif
            var rendered = parser.RenderPrDetail(detail)
            cur.file_map = rendered.file_map
            cur.current_file = ''
            buffer.SetLines(cur.detail_bufnr, rendered.lines)
            buffer.ResetWindowTop(cur.detail_winid)
        },
    })
enddef

def LoadPrDiff(view_id: number, num_str: string)
    var key = view.GetKey(view_id)
    if !has_key(views, key) || num_str == ''
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'pr',
        'diff',
        num_str,
        '--color=never',
    ] + RepoFlags(state)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_sub_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load PR diff.'] : res.stderr
                cur.pr_diff_lines = err
                buffer.SetLines(cur.sub_bufnr, err)
                return
            endif
            var lines = empty(res.stdout) ? ['(No diff change)'] : res.stdout
            cur.pr_diff_lines = lines
            var display_lines = cur.current_file != '' ? parser.FilterDiffByFile(lines, cur.current_file) : lines
            buffer.SetLines(cur.sub_bufnr, display_lines)
            buffer.ResetWindowTop(cur.sub_winid)
        },
    })
enddef

def LoadPrList(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'pr',
        'list',
        '--json',
        'number,title,state,isDraft,author,headRefName,baseRefName,labels,reviewDecision,updatedAt,url',
    ]
    if !HasLimitArg(state.extra_args)
        extend(args, ['--limit', '50'])
    endif
    extend(args, state.extra_args)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_list_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load pull requests.'] : res.stderr
                buffer.SetLines(cur.list_bufnr, err)
                if cur.target == ''
                    buffer.SetLines(cur.detail_bufnr, err)
                    buffer.SetLines(cur.sub_bufnr, [])
                endif
                return
            endif

            var prs = parser.ParsePrList(res.stdout)
            var rendered = parser.RenderPrList(prs)
            cur.line_map = rendered.line_map
            buffer.SetLines(cur.list_bufnr, rendered.lines)

            var target_lnum: number = 1
            var desired_num = cur.target != '' ? cur.target : cur.current_number
            if desired_num != ''
                for [l_str, ent] in items(cur.line_map)
                    if parser.ToStr(get(ent, 'number', '')) == desired_num
                        target_lnum = str2nr(l_str)
                        break
                    endif
                endfor
            endif

            if cur.list_winid > 0 && win_id2win(cur.list_winid) > 0
                win_execute(cur.list_winid, printf('normal! %dG0', target_lnum))
            endif

            if cur.target != '' && desired_num == cur.target
                cur.current_number = cur.target
                LoadPrDetail(view_id, cur.target)
                LoadPrDiff(view_id, cur.target)
            elseif has_key(cur.line_map, string(target_lnum))
                var ent = cur.line_map[string(target_lnum)]
                var num_str = parser.ToStr(get(ent, 'number', ''))
                cur.current_number = num_str
                cur.current_url = parser.ToStr(get(ent, 'url', ''))
                LoadPrDetail(view_id, num_str)
                LoadPrDiff(view_id, num_str)
            else
                buffer.SetLines(cur.detail_bufnr, ['(No pull request selected)'])
                buffer.SetLines(cur.sub_bufnr, [])
            endif
        },
    })
enddef

def RenderCurrentProjectDetail(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var cur = views[key]
    if !cur.proj_view_done || !cur.proj_items_done
        return
    endif

    var rendered = parser.RenderProjectDetail(cur.proj_detail, cur.proj_items)
    cur.item_map = rendered.item_map
    cur.current_item_idx = ''
    buffer.SetLines(cur.detail_bufnr, rendered.lines)
    buffer.ResetWindowTop(cur.detail_winid)

    if !empty(cur.proj_items)
        buffer.SetLines(cur.sub_bufnr, parser.RenderProjectItemDetail(cur.proj_items[0]))
    else
        buffer.SetLines(cur.sub_bufnr, ['(No items in this project)'])
    endif
    buffer.ResetWindowTop(cur.sub_winid)
enddef

def LoadProjectDetail(view_id: number, num_str: string, owner_override: string = '')
    var key = view.GetKey(view_id)
    if !has_key(views, key) || num_str == ''
        return
    endif
    var state = views[key]
    state.proj_view_done = false
    state.proj_items_done = false
    state.proj_detail = {}
    state.proj_items = []

    var owner_flags = OwnerFlags(state, owner_override)
    var view_args: list<string> = ['project', 'view', num_str, '--format', 'json'] + owner_flags
    var items_args: list<string> = ['project', 'item-list', num_str, '--format', 'json', '--limit', '100'] + owner_flags

    gh.Run(view_args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_detail_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            cur.proj_view_done = true
            if res.status == 0
                cur.proj_detail = parser.ParseProjectDetail(res.stdout)
                var url = parser.ToStr(get(cur.proj_detail, 'url', ''))
                if url != ''
                    cur.current_url = url
                endif
            endif
            RenderCurrentProjectDetail(view_id)
        },
    })

    gh.Run(items_args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_sub_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            cur.proj_items_done = true
            if res.status == 0
                cur.proj_items = parser.ParseProjectItems(res.stdout)
            endif
            RenderCurrentProjectDetail(view_id)
        },
    })
enddef

def LoadProjectList(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]

    var args: list<string> = [
        'project',
        'list',
        '--format',
        'json',
    ]
    if !HasLimitArg(state.extra_args)
        extend(args, ['--limit', '30'])
    endif
    var has_owner_in_extra = false
    for a in state.extra_args
        if a == '--owner' || a =~ '^--owner='
            has_owner_in_extra = true
            break
        endif
    endfor
    if !has_owner_in_extra && state.owner != ''
        extend(args, ['--owner', state.owner])
    endif
    extend(args, state.extra_args)

    gh.Run(args, {
        cwd: state.cwd,
        task_key: 'gitu_gh_list_' .. key,
        on_exit: (res: dict<any>) => {
            if !has_key(views, key)
                return
            endif
            var cur = views[key]
            if res.status != 0
                var err = empty(res.stderr) ? ['Failed to load projects.'] : res.stderr
                buffer.SetLines(cur.list_bufnr, err)
                if cur.target == ''
                    buffer.SetLines(cur.detail_bufnr, err)
                    buffer.SetLines(cur.sub_bufnr, [])
                endif
                return
            endif

            var projects = parser.ParseProjectList(res.stdout)
            var rendered = parser.RenderProjectList(projects)
            cur.line_map = rendered.line_map
            buffer.SetLines(cur.list_bufnr, rendered.lines)

            var target_lnum: number = 1
            var desired_num = cur.target != '' ? cur.target : cur.current_number
            if desired_num != ''
                for [l_str, ent] in items(cur.line_map)
                    if parser.ToStr(get(ent, 'number', '')) == desired_num
                        target_lnum = str2nr(l_str)
                        break
                    endif
                endfor
            endif

            if cur.list_winid > 0 && win_id2win(cur.list_winid) > 0
                win_execute(cur.list_winid, printf('normal! %dG0', target_lnum))
            endif

            if cur.target != '' && desired_num == cur.target
                cur.current_number = cur.target
                LoadProjectDetail(view_id, cur.target, cur.owner)
            elseif has_key(cur.line_map, string(target_lnum))
                var ent = cur.line_map[string(target_lnum)]
                var num_str = parser.ToStr(get(ent, 'number', ''))
                var owner_val = get(ent, 'owner', {})
                var ent_owner = type(owner_val) == v:t_dict ? parser.ToStr(get(owner_val, 'login', '')) : ''
                cur.current_number = num_str
                cur.current_url = parser.ToStr(get(ent, 'url', ''))
                LoadProjectDetail(view_id, num_str, ent_owner)
            else
                buffer.SetLines(cur.detail_bufnr, ['(No project selected)'])
                buffer.SetLines(cur.sub_bufnr, [])
            endif
        },
    })
enddef

def LoadByKind(view_id: number)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.kind == 'issue'
        if state.target != ''
            LoadIssueDetail(view_id, state.target)
        endif
        LoadIssueList(view_id)
    elseif state.kind == 'pr'
        if state.target != ''
            LoadPrDetail(view_id, state.target)
            LoadPrDiff(view_id, state.target)
        endif
        LoadPrList(view_id)
    elseif state.kind == 'project'
        if state.owner == ''
            state.owner = gh.ResolveRepoOwner(state.cwd)
        endif
        if state.target != ''
            LoadProjectDetail(view_id, state.target, state.owner)
        endif
        LoadProjectList(view_id)
    endif
enddef

def SetupSubDiffKeymaps()
    nnoremap <buffer> <silent> q <ScriptCmd>gitu#gh#view#Close()<CR>
    nnoremap <buffer> <silent> u <ScriptCmd>gitu#gh#view#Refresh()<CR>
    nnoremap <buffer> <silent> go <ScriptCmd>gitu#gh#view#OpenWeb()<CR>
    nnoremap <buffer> <silent> yy <ScriptCmd>gitu#gh#view#YankNumber()<CR>
    nnoremap <buffer> <silent> <expr> <C-j> v:count1 .. "\<C-e>"
    nnoremap <buffer> <silent> <expr> <C-k> v:count1 .. "\<C-y>"
    nnoremap <buffer> <silent> <Tab> <ScriptCmd>gitu#gh#view#CycleFocus(1)<CR>
    nnoremap <buffer> <silent> <S-Tab> <ScriptCmd>gitu#gh#view#CycleFocus(-1)<CR>
enddef

def OpenByKind(kind: string, raw_args: list<string>)
    if !gh.EnsureAvailable()
        return
    endif

    var parsed_args = parser.NormalizeArgs(raw_args)
    var initial_cwd: string = git.ResolveInitialCwd()

    next_view_id += 1
    var view_id: number = next_view_id
    var key: string = view.GetKey(view_id)

    var label = kind == 'issue' ? 'Issue' : (kind == 'pr' ? 'PR' : 'Project')

    tabnew
    t:gitu_view_id = view_id

    var list_winid: number = win_getid()
    var list_bufnr: number = buffer.InitCurrentScratch('gitu-gh-list', printf('[GitU:%s #%s]', label, key))
    b:gitu_view_id = view_id

    rightbelow vnew
    var detail_winid: number = win_getid()
    var detail_bufnr: number = buffer.InitCurrentScratch('gitu-gh-detail', printf('[GitU:%sDetail #%s]', label, key))
    b:gitu_view_id = view_id

    var sub_winid: number = -1
    var sub_bufnr: number = -1

    if kind == 'pr'
        rightbelow new
        sub_winid = win_getid()
        sub_bufnr = buffer.InitCurrentScratch('gitu-diff', printf('[GitU:PRDiff #%s]', key))
        b:gitu_view_id = view_id
        SetupSubDiffKeymaps()
    elseif kind == 'project'
        rightbelow new
        sub_winid = win_getid()
        sub_bufnr = buffer.InitCurrentScratch('gitu-gh-detail', printf('[GitU:ProjectItem #%s]', key))
        b:gitu_view_id = view_id
    endif

    if sub_winid > 0
        var detail_height: number = get(g:, 'gitu_commit_height', 15)
        if detail_height > 0
            win_execute(detail_winid, 'resize ' .. string(detail_height))
        endif
    endif

    win_gotoid(list_winid)

    views[key] = {
        id: view_id,
        kind: kind,
        cwd: initial_cwd,
        mode: parsed_args.mode,
        target: parsed_args.target,
        extra_args: parsed_args.extra_args,
        repo: parsed_args.repo,
        owner: parsed_args.owner,
        list_bufnr: list_bufnr,
        list_winid: list_winid,
        detail_bufnr: detail_bufnr,
        detail_winid: detail_winid,
        sub_bufnr: sub_bufnr,
        sub_winid: sub_winid,
        line_map: {},
        file_map: {},
        item_map: {},
        current_number: parsed_args.target,
        current_url: '',
        current_file: '',
        current_item_idx: '',
        pr_diff_lines: [],
        proj_detail: {},
        proj_items: [],
        proj_view_done: false,
        proj_items_done: false,
        cursor_timer: -1,
    }

    buffer.SetLines(list_bufnr, [printf('Loading %s list...', kind)])
    buffer.SetLines(detail_bufnr, [printf('Loading %s details...', kind)])
    if sub_bufnr > 0
        buffer.SetLines(sub_bufnr, ['Loading...'])
    endif

    git.ResolveRepoRoot(initial_cwd, (root: string, _stderr: list<string>) => {
        if !has_key(views, key)
            return
        endif
        if root != ''
            views[key].cwd = root
        endif
        LoadByKind(view_id)
    })
enddef

export def OpenIssue(...args: list<string>)
    OpenByKind('issue', args)
enddef

export def OpenPr(...args: list<string>)
    OpenByKind('pr', args)
enddef

export def OpenProject(...args: list<string>)
    OpenByKind('project', args)
enddef

export def Open(...args: list<string>)
    if empty(args)
        OpenIssue()
        return
    endif
    var sub = args[0]
    var rest = len(args) > 1 ? args[1 :] : []
    if sub == 'issue' || sub == 'issues'
        OpenByKind('issue', rest)
    elseif sub == 'pr' || sub == 'prs' || sub == 'pull'
        OpenByKind('pr', rest)
    elseif sub == 'project' || sub == 'projects'
        OpenByKind('project', rest)
    else
        notify.Error('Unknown GitUGh subcommand: ' .. sub .. ' (expected: issue, pr, project)')
    endif
enddef

export def Refresh()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    state.target = ''
    LoadByKind(view_id)
enddef

def DoListCursorMoved(view_id: number, force: bool)
    var key = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var lnum_str = string(line('.'))
    if !has_key(state.line_map, lnum_str)
        return
    endif
    var ent = state.line_map[lnum_str]
    var num_str = parser.ToStr(get(ent, 'number', ''))
    if num_str == ''
        return
    endif
    if !force && num_str == state.current_number
        return
    endif

    state.current_number = num_str
    state.current_url = parser.ToStr(get(ent, 'url', ''))
    state.target = ''

    if state.kind == 'issue'
        LoadIssueDetail(view_id, num_str)
    elseif state.kind == 'pr'
        LoadPrDetail(view_id, num_str)
        LoadPrDiff(view_id, num_str)
    elseif state.kind == 'project'
        var owner_val = get(ent, 'owner', {})
        var ent_owner = type(owner_val) == v:t_dict ? parser.ToStr(get(owner_val, 'login', '')) : ''
        LoadProjectDetail(view_id, num_str, ent_owner)
    endif
enddef

export def OnListCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.cursor_timer > 0
        timer_stop(state.cursor_timer)
        state.cursor_timer = -1
    endif

    if force
        DoListCursorMoved(view_id, true)
    else
        state.cursor_timer = timer_start(50, (_) => {
            if has_key(views, key)
                views[key].cursor_timer = -1
                DoListCursorMoved(view_id, false)
            endif
        })
    endif
enddef

export def OnDetailCursorMoved(force: bool = false)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if win_getid() != state.detail_winid
        return
    endif

    var lnum_str = string(line('.'))
    if state.kind == 'pr'
        var file_path = get(state.file_map, lnum_str, '')
        if !force && file_path == state.current_file
            return
        endif
        state.current_file = file_path
        var display_lines = file_path != ''
            ? parser.FilterDiffByFile(state.pr_diff_lines, file_path)
            : state.pr_diff_lines
        if !empty(display_lines)
            buffer.SetLines(state.sub_bufnr, display_lines)
            buffer.ResetWindowTop(state.sub_winid)
        endif
    elseif state.kind == 'project'
        if !has_key(state.item_map, lnum_str)
            return
        endif
        if !force && lnum_str == state.current_item_idx
            return
        endif
        state.current_item_idx = lnum_str
        var item = state.item_map[lnum_str]
        buffer.SetLines(state.sub_bufnr, parser.RenderProjectItemDetail(item))
        buffer.ResetWindowTop(state.sub_winid)
    endif
enddef

export def SelectDetailItem()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    OnDetailCursorMoved(true)
    if state.sub_winid > 0 && win_id2win(state.sub_winid) > 0
        win_gotoid(state.sub_winid)
    endif
enddef

export def MoveSubView(direction: number, count: number = 1)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var target_winid = state.detail_winid
    if state.sub_winid > 0 && win_id2win(state.sub_winid) > 0
        if win_getid() == state.detail_winid || state.kind == 'pr'
            target_winid = state.sub_winid
        endif
    endif
    if target_winid > 0 && win_id2win(target_winid) > 0
        var scroll_char = direction > 0 ? "\<C-e>" : "\<C-y>"
        var feed_cmd = printf('call feedkeys("%d%s", "xt")', count, scroll_char)
        win_execute(target_winid, feed_cmd)
        redraw
    endif
enddef

export def CycleFocus(direction: number = 1)
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var wins: list<number> = [state.list_winid, state.detail_winid]
    if state.sub_winid > 0 && win_id2win(state.sub_winid) > 0
        add(wins, state.sub_winid)
    endif
    var cur_winid = win_getid()
    var idx = index(wins, cur_winid)
    if idx < 0
        win_gotoid(wins[0])
        return
    endif
    var next_idx = (idx + direction + len(wins)) % len(wins)
    win_gotoid(wins[next_idx])
enddef

export def OpenWeb()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    var url = state.current_url

    if state.kind == 'project' && win_getid() == state.detail_winid
        var lnum_str = string(line('.'))
        if has_key(state.item_map, lnum_str)
            var item = state.item_map[lnum_str]
            var content = get(item, 'content', {})
            if type(content) == v:t_dict && get(content, 'url', '') != ''
                url = parser.ToStr(content.url)
            endif
        endif
    endif

    if url == ''
        notify.Warn('No URL available for current item.')
        return
    endif
    github.OpenBrowser(url)
    notify.Info('Opening ' .. url)
enddef

export def YankNumber()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if !has_key(views, key)
        return
    endif
    var state = views[key]
    if state.current_number == ''
        return
    endif
    var val = '#' .. state.current_number
    setreg('"', val)
    silent! setreg('+', val)
    silent! setreg('*', val)
    notify.Info('Yanked ' .. val)
enddef

export def GetState(view_id: number = -1): dict<any>
    var id = view_id > 0 ? view_id : view.GetCurrentId()
    return get(views, view.GetKey(id), {})
enddef

export def OnBufWipeout()
    var view_id: number = view.GetCurrentId()
    var key: string = view.GetKey(view_id)
    if has_key(views, key)
        var state = views[key]
        if state.cursor_timer > 0
            timer_stop(state.cursor_timer)
            state.cursor_timer = -1
        endif
        gh.StopByKey('gitu_gh_list_' .. key)
        gh.StopByKey('gitu_gh_detail_' .. key)
        gh.StopByKey('gitu_gh_sub_' .. key)
        remove(views, key)
    endif
enddef

export def Close()
    OnBufWipeout()
    buffer.CloseTabOrReset()
enddef
