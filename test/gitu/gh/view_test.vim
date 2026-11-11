vim9script

filetype plugin on

import autoload 'gitu/core/gh.vim'
import autoload 'gitu/gh/view.vim' as gh_view

def WaitFor(Condition: func(): bool, timeout: number = 3000): bool
    var start = reltime()
    while !Condition()
        if reltimefloat(reltime(start)) * 1000.0 > timeout
            return false
        endif
        sleep 20m
    endwhile
    return true
enddef

def CreateMockGh(temp_dir: string): string
    var mock_path = temp_dir .. '/mock_gh.sh'
    var lines = [
        '#!/bin/sh',
        'cmd="$1"',
        'sub="$2"',
        'if [ "$cmd" = "issue" ] && [ "$sub" = "list" ]; then',
        '  cat << ''EOF''',
        '[',
        '  {"number": 10, "state": "OPEN", "title": "First Issue", "author": {"login": "alice"}, "labels": [{"name": "bug"}], "url": "https://github.com/owner/repo/issues/10"},',
        '  {"number": 11, "state": "CLOSED", "title": "Second Issue", "author": {"login": "bob"}, "labels": [], "url": "https://github.com/owner/repo/issues/11"}',
        ']',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "issue" ] && [ "$sub" = "view" ]; then',
        '  num="$3"',
        '  cat << EOF',
        '{',
        '  "number": $num,',
        '  "state": "OPEN",',
        '  "title": "Issue #$num Title",',
        '  "author": {"login": "alice"},',
        '  "assignees": [{"login": "bob"}],',
        '  "labels": [{"name": "bug"}],',
        '  "createdAt": "2026-11-01T10:00:00Z",',
        '  "updatedAt": "2026-11-02T12:00:00Z",',
        '  "url": "https://github.com/owner/repo/issues/$num",',
        '  "body": "Body of issue $num",',
        '  "comments": [{"author": {"login": "charlie"}, "createdAt": "2026-11-02T11:00:00Z", "body": "Comment on $num"}]',
        '}',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "pr" ] && [ "$sub" = "list" ]; then',
        '  cat << ''EOF''',
        '[',
        '  {"number": 20, "state": "OPEN", "isDraft": false, "title": "First PR", "baseRefName": "main", "headRefName": "feat-1", "author": {"login": "alice"}, "labels": [], "url": "https://github.com/owner/repo/pull/20"},',
        '  {"number": 21, "state": "MERGED", "isDraft": false, "title": "Second PR", "baseRefName": "main", "headRefName": "feat-2", "author": {"login": "bob"}, "labels": [], "url": "https://github.com/owner/repo/pull/21"}',
        ']',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "pr" ] && [ "$sub" = "view" ]; then',
        '  num="$3"',
        '  cat << EOF',
        '{',
        '  "number": $num,',
        '  "state": "OPEN",',
        '  "isDraft": false,',
        '  "title": "PR #$num Title",',
        '  "author": {"login": "alice"},',
        '  "baseRefName": "main",',
        '  "headRefName": "feat-1",',
        '  "reviewDecision": "APPROVED",',
        '  "additions": 10,',
        '  "deletions": 2,',
        '  "changedFiles": 2,',
        '  "createdAt": "2026-11-01T10:00:00Z",',
        '  "updatedAt": "2026-11-02T12:00:00Z",',
        '  "url": "https://github.com/owner/repo/pull/$num",',
        '  "body": "PR description for $num",',
        '  "comments": [],',
        '  "files": [',
        '    {"path": "src/a.vim", "additions": 5, "deletions": 1},',
        '    {"path": "src/b.vim", "additions": 5, "deletions": 1}',
        '  ]',
        '}',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "pr" ] && [ "$sub" = "diff" ]; then',
        '  cat << ''EOF''',
        'diff --git a/src/a.vim b/src/a.vim',
        '--- a/src/a.vim',
        '+++ b/src/a.vim',
        '@@ -1 +1 @@',
        '-old a',
        '+new a',
        'diff --git a/src/b.vim b/src/b.vim',
        '--- a/src/b.vim',
        '+++ b/src/b.vim',
        '@@ -1 +1 @@',
        '-old b',
        '+new b',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "project" ] && [ "$sub" = "list" ]; then',
        '  cat << ''EOF''',
        '{',
        '  "projects": [',
        '    {"number": 1, "title": "Roadmap 2026", "closed": false, "items": {"totalCount": 2}, "owner": {"login": "yasuhiroki"}, "url": "https://github.com/users/yasuhiroki/projects/1"}',
        '  ]',
        '}',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "project" ] && [ "$sub" = "view" ]; then',
        '  cat << ''EOF''',
        '{',
        '  "number": 1,',
        '  "title": "Roadmap 2026",',
        '  "closed": false,',
        '  "shortDescription": "Yearly plan",',
        '  "readme": "Welcome to Roadmap 2026",',
        '  "owner": {"login": "yasuhiroki"},',
        '  "items": {"totalCount": 2},',
        '  "url": "https://github.com/users/yasuhiroki/projects/1"',
        '}',
        'EOF',
        '  exit 0',
        'fi',
        'if [ "$cmd" = "project" ] && [ "$sub" = "item-list" ]; then',
        '  cat << ''EOF''',
        '{',
        '  "items": [',
        '    {"status": "Todo", "title": "Task One", "assignees": ["alice"], "labels": ["v1"], "content": {"type": "Issue", "number": 10, "title": "Task One", "repository": "owner/repo", "url": "https://github.com/owner/repo/issues/10", "body": "Task One body"}},',
        '    {"status": "Done", "title": "Task Two", "assignees": ["bob"], "labels": [], "content": {"type": "PullRequest", "number": 20, "title": "Task Two", "repository": "owner/repo", "url": "https://github.com/owner/repo/pull/20", "body": "Task Two body"}}',
        '  ]',
        '}',
        'EOF',
        '  exit 0',
        'fi',
        'exit 1',
    ]
    writefile(lines, mock_path)
    setfperm(mock_path, 'rwxr-xr-x')
    return mock_path
enddef

def TestOptionalGhMissing()
    g:gitu_gh_executable = 'nonexistent_gh_binary_xyz_12345'
    try
        assert_false(gh.IsAvailable())
        var tabs_before = tabpagenr('$')
        gh_view.OpenIssue()
        assert_equal(tabs_before, tabpagenr('$'), 'Should not open tab when gh is missing')
    finally
        unlet! g:gitu_gh_executable
    endtry
enddef

def TestIssueListAndShow()
    var temp_dir = fnamemodify('./tmp/test_gh_issue_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')
    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    var mock_gh = CreateMockGh(temp_dir)
    g:gitu_gh_executable = mock_gh
    var orig_cwd = getcwd()

    try
        execute 'cd ' .. fnameescape(temp_dir)
        gh_view.OpenIssue()

        var state = gh_view.GetState()
        var ok = WaitFor((): bool => len(keys(state.line_map)) == 2 && getbufline(state.detail_bufnr, 1)[0] =~ '^Issue:\s\+#10', 3000)
        assert_true(ok, 'Timed out waiting for issue list and detail #10')

        assert_equal(state.list_winid, win_getid(), 'Focus should start on issue list')

        # Move cursor to line 2 (#11) and trigger load
        cursor(2, 1)
        gh_view.OnListCursorMoved(true)

        var ok2 = WaitFor((): bool => getbufline(state.detail_bufnr, 1)[0] =~ '^Issue:\s\+#11', 3000)
        assert_true(ok2, 'Detail pane should update to issue #11')

        # Yank issue number
        gh_view.YankNumber()
        assert_equal('#11', getreg('"'))

        # Cycle focus
        gh_view.CycleFocus(1)
        assert_equal(state.detail_winid, win_getid())
        gh_view.CycleFocus(1)
        assert_equal(state.list_winid, win_getid())

        gh_view.Close()
    finally
        unlet! g:gitu_gh_executable
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def TestPrListShowAndFileFilter()
    var temp_dir = fnamemodify('./tmp/test_gh_pr_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')
    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    var mock_gh = CreateMockGh(temp_dir)
    g:gitu_gh_executable = mock_gh
    var orig_cwd = getcwd()

    try
        execute 'cd ' .. fnameescape(temp_dir)
        gh_view.OpenPr('show', '20')

        var state = gh_view.GetState()
        var ok = WaitFor((): bool => len(keys(state.line_map)) == 2 && len(state.pr_diff_lines) > 0 && !empty(state.file_map), 3000)
        assert_true(ok, 'Timed out waiting for PR list, detail, and diff')

        assert_true(state.sub_winid > 0, 'PR view should have diff sub window')
        var diff_lines = getbufline(state.sub_bufnr, 1, '$')
        assert_true(index(diff_lines, '+new a') >= 0)
        assert_true(index(diff_lines, '+new b') >= 0)

        # Move focus to detail pane and move cursor to src/b.vim line
        win_gotoid(state.detail_winid)
        var target_file_lnum = -1
        for [l_str, fpath] in items(state.file_map)
            if fpath == 'src/b.vim'
                target_file_lnum = str2nr(l_str)
                break
            endif
        endfor
        assert_true(target_file_lnum > 0, 'src/b.vim should be in file_map')

        cursor(target_file_lnum, 1)
        gh_view.SelectDetailItem()
        assert_equal(state.sub_winid, win_getid(), 'SelectDetailItem should jump to diff pane')

        var filtered_diff = getbufline(state.sub_bufnr, 1, '$')
        assert_true(index(filtered_diff, '+new b') >= 0, 'Filtered diff should contain src/b.vim changes')
        assert_false(index(filtered_diff, '+new a') >= 0, 'Filtered diff should not contain src/a.vim changes')

        gh_view.Close()
    finally
        unlet! g:gitu_gh_executable
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def TestProjectListShowAndItemSelect()
    var temp_dir = fnamemodify('./tmp/test_gh_proj_' .. localtime(), ':p')
    mkdir(temp_dir, 'p')
    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    var mock_gh = CreateMockGh(temp_dir)
    g:gitu_gh_executable = mock_gh
    var orig_cwd = getcwd()

    try
        execute 'cd ' .. fnameescape(temp_dir)
        gh_view.OpenProject()

        var state = gh_view.GetState()
        var ok = WaitFor((): bool => state.proj_view_done && state.proj_items_done && !empty(state.item_map), 3000)
        assert_true(ok, 'Timed out waiting for project view and items')

        # First item should be displayed in sub pane automatically
        var item1_lines = getbufline(state.sub_bufnr, 1, '$')
        assert_true(index(item1_lines, 'Item:       #10 Task One') >= 0)

        # Move to second item in detail pane
        win_gotoid(state.detail_winid)
        var item_lnums = sort(map(keys(state.item_map), (_, k: string): number => str2nr(k)))
        assert_equal(2, len(item_lnums))
        cursor(item_lnums[1], 1)
        gh_view.OnDetailCursorMoved(true)

        var item2_lines = getbufline(state.sub_bufnr, 1, '$')
        assert_true(index(item2_lines, 'Item:       #20 Task Two') >= 0)
        assert_true(index(item2_lines, 'Type:       PullRequest') >= 0)

        gh_view.Close()
    finally
        unlet! g:gitu_gh_executable
        execute 'cd ' .. fnameescape(orig_cwd)
        delete(temp_dir, 'rf')
    endtry
enddef

def TestCompletions()
    var ic = gh_view.CompleteIssue('--s', 'GitUIssue --s', 13)
    assert_true(index(ic, '--state') >= 0)
    assert_true(index(ic, '--search') >= 0)

    var pc = gh_view.CompletePr('--d', 'GitUPr --d', 10)
    assert_equal(['--draft'], pc)

    var prjc = gh_view.CompleteProject('--o', 'GitUProject --o', 15)
    assert_equal(['--owner'], prjc)

    var ghc = gh_view.CompleteGh('', 'GitUGh ', 7)
    assert_equal(['issue', 'pr', 'project'], ghc)
enddef

def RunAll()
    TestOptionalGhMissing()
    TestIssueListAndShow()
    TestPrListShowAndFileFilter()
    TestProjectListShowAndItemSelect()
    TestCompletions()

    if len(v:errors) > 0
        for err in v:errors
            echomsg err
        endfor
        cquit!
    endif
    qall!
enddef

RunAll()
