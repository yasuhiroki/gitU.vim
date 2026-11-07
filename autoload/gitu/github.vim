vim9script

export def ParseGitHubRepoUrl(raw: string): string
    var clean = trim(raw)
    var u = substitute(clean, '\.git$', '', '')
    var m = matchlist(u, '\vgithub\.com[:/]([^/]+)/([^/]+)$')
    if len(m) >= 3 && m[1] != '' && m[2] != ''
        return printf('https://github.com/%s/%s', m[1], m[2])
    endif
    return ''
enddef

export def GetGitHubRepoUrl(cwd: string): string
    var remotes_out = system('git -C ' .. fnameescape(cwd) .. ' remote')
    var remotes = split(remotes_out, "\n")
    if empty(remotes)
        return ''
    endif

    var target_remotes = ['upstream', 'origin']
    for r in remotes
        if index(target_remotes, r) < 0
            add(target_remotes, r)
        endif
    endfor

    for r in target_remotes
        var url_out = trim(system('git -C ' .. fnameescape(cwd) .. ' remote get-url ' .. fnameescape(r)))
        if v:shell_error == 0 && url_out != ''
            var parsed = ParseGitHubRepoUrl(url_out)
            if parsed != ''
                return parsed
            endif
        endif
    endfor

    return ''
enddef

export def ExtractPrNumber(text: string): string
    var m = matchlist(text, '\v%(Merge pull request #|\(#)(\d+)')
    if len(m) >= 2 && m[1] != ''
        return m[1]
    endif
    return ''
enddef

export def ResolvePrUrl(cwd: string, repo_url: string, hash: string): string
    # 1. Check commit message directly
    var msg = system('git -C ' .. fnameescape(cwd) .. ' show -s --format=%B ' .. fnameescape(hash))
    if v:shell_error == 0 && msg != ''
        var pr_num = ExtractPrNumber(msg)
        if pr_num != ''
            return printf('%s/pull/%s', repo_url, pr_num)
        endif
    endif

    # 2. Check merge commits in ancestry path
    var merge_log = system('git -C ' .. fnameescape(cwd) .. ' log --merges --ancestry-path --reverse --format=%s ' .. fnameescape(hash) .. '..HEAD')
    if v:shell_error == 0 && merge_log != ''
        for line in split(merge_log, "\n")
            var pr_num = ExtractPrNumber(line)
            if pr_num != ''
                return printf('%s/pull/%s', repo_url, pr_num)
            endif
        endfor
    endif

    # 3. Direct to GitHub Pull Request search by commit hash
    return printf('%s/pulls?q=is%%3Apr+%s', repo_url, hash)
enddef

export def OpenBrowser(url: string)
    if url == ''
        return
    endif

    var cmd: list<string> = []
    if has('mac') || has('macunix')
        cmd = ['open', url]
    elseif has('win32') || has('win64')
        cmd = ['cmd.exe', '/c', 'start', '', url]
    elseif executable('wslview')
        cmd = ['wslview', url]
    elseif executable('xdg-open')
        cmd = ['xdg-open', url]
    elseif executable('sensible-browser')
        cmd = ['sensible-browser', url]
    endif

    if !empty(cmd)
        job_start(cmd)
    else
        echohl ErrorMsg
        echomsg 'No browser launcher found (open, xdg-open, etc.)'
        echohl None
    endif
enddef

export def OpenCommit(cwd: string, hash: string)
    var repo_url = GetGitHubRepoUrl(cwd)
    if repo_url == ''
        echohl WarningMsg
        echomsg 'Could not detect GitHub repository from git remotes'
        echohl None
        return
    endif

    var url = printf('%s/commit/%s', repo_url, hash)
    OpenBrowser(url)
    echomsg 'Opening ' .. url
enddef

export def OpenPullRequest(cwd: string, hash: string)
    var repo_url = GetGitHubRepoUrl(cwd)
    if repo_url == ''
        echohl WarningMsg
        echomsg 'Could not detect GitHub repository from git remotes'
        echohl None
        return
    endif

    var url = ResolvePrUrl(cwd, repo_url, hash)
    OpenBrowser(url)
    echomsg 'Opening ' .. url
enddef
