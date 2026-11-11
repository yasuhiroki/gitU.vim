vim9script

import autoload 'gitu/gh/parser.vim'

def TestNormalizeArgs()
    var r1 = parser.NormalizeArgs([])
    assert_equal('list', r1.mode)
    assert_equal('', r1.target)
    assert_equal([], r1.extra_args)

    var r2 = parser.NormalizeArgs(['list', '--state', 'all'])
    assert_equal('list', r2.mode)
    assert_equal('', r2.target)
    assert_equal(['--state', 'all'], r2.extra_args)

    var r3 = parser.NormalizeArgs(['show', '#42', '-R', 'owner/repo'])
    assert_equal('show', r3.mode)
    assert_equal('42', r3.target)
    assert_equal('owner/repo', r3.repo)

    var r4 = parser.NormalizeArgs(['105', '--owner', 'myorg'])
    assert_equal('show', r4.mode)
    assert_equal('105', r4.target)
    assert_equal('myorg', r4.owner)
enddef

def TestIssueParsingAndRendering()
    var json_lines = [
        '[',
        '  {"number": 12, "state": "OPEN", "title": "Fix crash on startup", "author": {"login": "alice"}, "labels": [{"name": "bug"}, {"name": "high"}]},',
        '  {"number": 9, "state": "CLOSED", "title": "Add docs", "author": {"login": "bob"}, "labels": []}',
        ']',
    ]
    var issues = parser.ParseIssueList(json_lines)
    assert_equal(2, len(issues))

    var rendered = parser.RenderIssueList(issues)
    assert_equal(2, len(rendered.lines))
    assert_match('^#12\s\+\[OPEN\]\s\+Fix crash on startup \[bug, high\] (@alice)$', rendered.lines[0])
    assert_match('^#9\s\+\[CLOSED\]\s\+Add docs (@bob)$', rendered.lines[1])
    assert_equal(12, rendered.line_map['1'].number)
    assert_equal(9, rendered.line_map['2'].number)

    var detail_json = [
        '{',
        '  "number": 12,',
        '  "state": "OPEN",',
        '  "title": "Fix crash on startup",',
        '  "author": {"login": "alice"},',
        '  "assignees": [{"login": "charlie"}],',
        '  "labels": [{"name": "bug"}],',
        '  "milestone": {"title": "v1.0"},',
        '  "createdAt": "2026-11-01T09:15:00Z",',
        '  "updatedAt": "2026-11-02T14:20:00Z",',
        '  "url": "https://github.com/owner/repo/issues/12",',
        '  "body": "Steps to reproduce:\n1. Run command\n2. Observe crash",',
        '  "comments": [',
        '    {"author": {"login": "dave"}, "createdAt": "2026-11-02T10:00:00Z", "body": "Working on a fix."}',
        '  ]',
        '}',
    ]
    var detail = parser.ParseIssueDetail(detail_json)
    var detail_lines = parser.RenderIssueDetail(detail)
    assert_true(index(detail_lines, 'Issue:     #12 [OPEN]') >= 0)
    assert_true(index(detail_lines, 'Title:     Fix crash on startup') >= 0)
    assert_true(index(detail_lines, 'Author:    @alice') >= 0)
    assert_true(index(detail_lines, 'Assignees: @charlie') >= 0)
    assert_true(index(detail_lines, 'Milestone: v1.0') >= 0)
    assert_true(index(detail_lines, '--- Description ---') >= 0)
    assert_true(index(detail_lines, '--- Comments (1) ---') >= 0)
    assert_true(index(detail_lines, '  Working on a fix.') >= 0)
enddef

def TestPrParsingAndRendering()
    var json_lines = [
        '[',
        '  {"number": 45, "state": "OPEN", "isDraft": true, "title": "WIP feature", "baseRefName": "main", "headRefName": "feat-x", "author": {"login": "alice"}, "labels": []},',
        '  {"number": 40, "state": "MERGED", "isDraft": false, "title": "Refactor core", "baseRefName": "main", "headRefName": "refactor", "author": {"login": "bob"}, "labels": [{"name": "clean"}]}',
        ']',
    ]
    var prs = parser.ParsePrList(json_lines)
    var rendered = parser.RenderPrList(prs)
    assert_equal(2, len(rendered.lines))
    assert_match('^#45\s\+\[DRAFT\]\s\+WIP feature (main <- feat-x) (@alice)$', rendered.lines[0])
    assert_match('^#40\s\+\[MERGED\]\s\+Refactor core (main <- refactor) \[clean\] (@bob)$', rendered.lines[1])

    var pr_detail_json = [
        '{',
        '  "number": 40,',
        '  "state": "MERGED",',
        '  "isDraft": false,',
        '  "title": "Refactor core",',
        '  "author": {"login": "bob"},',
        '  "baseRefName": "main",',
        '  "headRefName": "refactor",',
        '  "reviewDecision": "APPROVED",',
        '  "additions": 25,',
        '  "deletions": 10,',
        '  "changedFiles": 2,',
        '  "createdAt": "2026-11-01T08:00:00Z",',
        '  "updatedAt": "2026-11-01T12:00:00Z",',
        '  "url": "https://github.com/owner/repo/pull/40",',
        '  "body": "Refactored core modules.",',
        '  "comments": [],',
        '  "files": [',
        '    {"path": "autoload/a.vim", "additions": 15, "deletions": 5},',
        '    {"path": "autoload/b.vim", "additions": 10, "deletions": 5}',
        '  ]',
        '}',
    ]
    var pr_detail = parser.ParsePrDetail(pr_detail_json)
    var pr_rendered = parser.RenderPrDetail(pr_detail)
    assert_true(index(pr_rendered.lines, 'PR:        #40 [MERGED] (+25 / -10 in 2 files)') >= 0)
    assert_true(index(pr_rendered.lines, 'Branch:    main <- refactor') >= 0)
    assert_true(index(pr_rendered.lines, 'Review:    APPROVED') >= 0)
    assert_true(index(pr_rendered.lines, '--- Files ---') >= 0)
    assert_equal(2, len(keys(pr_rendered.file_map)))

    var diff_lines = [
        'diff --git a/autoload/a.vim b/autoload/a.vim',
        '--- a/autoload/a.vim',
        '+++ b/autoload/a.vim',
        '@@ -1 +1 @@',
        '-old a',
        '+new a',
        'diff --git a/autoload/b.vim b/autoload/b.vim',
        '--- a/autoload/b.vim',
        '+++ b/autoload/b.vim',
        '@@ -1 +1 @@',
        '-old b',
        '+new b',
    ]
    var filtered = parser.FilterDiffByFile(diff_lines, 'autoload/b.vim')
    assert_equal(6, len(filtered))
    assert_equal('+new b', filtered[5])
enddef

def TestProjectParsingAndRendering()
    var proj_list_json = [
        '{',
        '  "projects": [',
        '    {"number": 1, "title": "Q4 Roadmap", "closed": false, "items": {"totalCount": 3}, "owner": {"login": "yasuhiroki"}, "url": "https://github.com/users/yasuhiroki/projects/1"}',
        '  ]',
        '}',
    ]
    var projects = parser.ParseProjectList(proj_list_json)
    assert_equal(1, len(projects))
    var rendered_list = parser.RenderProjectList(projects)
    assert_match('^#1\s\+\[OPEN\]\s\+Q4 Roadmap (3 items) (@yasuhiroki)$', rendered_list.lines[0])

    var proj_detail_json = [
        '{',
        '  "number": 1,',
        '  "title": "Q4 Roadmap",',
        '  "closed": false,',
        '  "shortDescription": "Main milestones",',
        '  "readme": "Project overview text",',
        '  "owner": {"login": "yasuhiroki"},',
        '  "items": {"totalCount": 1},',
        '  "url": "https://github.com/users/yasuhiroki/projects/1"',
        '}',
    ]
    var items_json = [
        '{',
        '  "items": [',
        '    {',
        '      "status": "In Progress",',
        '      "title": "Add gh integration",',
        '      "assignees": ["yasuhiroki"],',
        '      "labels": ["feature"],',
        '      "content": {',
        '        "type": "Issue",',
        '        "number": 55,',
        '        "title": "Add gh integration",',
        '        "repository": "yasuhiroki/gitU.vim",',
        '        "url": "https://github.com/yasuhiroki/gitU.vim/issues/55",',
        '        "body": "Support issue, pr, project in GitU."',
        '      }',
        '    }',
        '  ]',
        '}',
    ]
    var proj_detail = parser.ParseProjectDetail(proj_detail_json)
    var proj_items = parser.ParseProjectItems(items_json)
    var rendered_detail = parser.RenderProjectDetail(proj_detail, proj_items)
    assert_true(index(rendered_detail.lines, 'Project:     #1 [OPEN]') >= 0)
    assert_true(index(rendered_detail.lines, '--- Readme ---') >= 0)
    assert_true(index(rendered_detail.lines, '--- Items (1) ---') >= 0)
    assert_equal(1, len(keys(rendered_detail.item_map)))

    var item_lines = parser.RenderProjectItemDetail(proj_items[0])
    assert_true(index(item_lines, 'Item:       #55 Add gh integration') >= 0)
    assert_true(index(item_lines, 'Type:       Issue') >= 0)
    assert_true(index(item_lines, 'Status:     In Progress') >= 0)
    assert_true(index(item_lines, 'Support issue, pr, project in GitU.') >= 0)
enddef

def RunAll()
    TestNormalizeArgs()
    TestIssueParsingAndRendering()
    TestPrParsingAndRendering()
    TestProjectParsingAndRendering()

    if len(v:errors) > 0
        for err in v:errors
            echomsg err
        endfor
        cquit!
    endif
    qall!
enddef

RunAll()
