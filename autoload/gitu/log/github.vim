vim9script

import autoload 'gitu/core/notify.vim'

export def ParseGitHubRepoUrl(raw: string): string
    var clean_url = substitute(trim(raw), '\.git$', '', '')
    var matches = matchlist(clean_url, '\vgithub\.com[:/]([^/]+)/([^/]+)$')
    if len(matches) >= 3 && matches[1] != '' && matches[2] != ''
        return printf('https://github.com/%s/%s', matches[1], matches[2])
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
    for remote_name in remotes
        if index(target_remotes, remote_name) < 0
            add(target_remotes, remote_name)
        endif
    endfor

    for remote_name in target_remotes
        var url_out = trim(system('git -C ' .. fnameescape(cwd) .. ' remote get-url ' .. fnameescape(remote_name)))
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
    var matches = matchlist(text, '\v%(Merge pull request #|\(#)(\d+)')
    if len(matches) >= 2 && matches[1] != ''
        return matches[1]
    endif
    return ''
enddef

export def ResolvePrUrl(cwd: string, repo_url: string, hash: string): string
    var msg = system('git -C ' .. fnameescape(cwd) .. ' show -s --format=%B ' .. fnameescape(hash))
    if v:shell_error == 0 && msg != ''
        var pr_num = ExtractPrNumber(msg)
        if pr_num != ''
            return printf('%s/pull/%s', repo_url, pr_num)
        endif
    endif

    var merge_log = system('git -C ' .. fnameescape(cwd) .. ' log --merges --ancestry-path --reverse --format=%s ' .. fnameescape(hash) .. '..HEAD')
    if v:shell_error == 0 && merge_log != ''
        for line in split(merge_log, "\n")
            var pr_num = ExtractPrNumber(line)
            if pr_num != ''
                return printf('%s/pull/%s', repo_url, pr_num)
            endif
        endfor
    endif

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
        notify.Error('No browser launcher found (open, xdg-open, etc.)')
    endif
enddef

export def OpenCommit(cwd: string, hash: string)
    var repo_url = GetGitHubRepoUrl(cwd)
    if repo_url == ''
        notify.Warn('Could not detect GitHub repository from git remotes')
        return
    endif

    var url = printf('%s/commit/%s', repo_url, hash)
    OpenBrowser(url)
    notify.Info('Opening ' .. url)
enddef

export def OpenPullRequest(cwd: string, hash: string)
    var repo_url = GetGitHubRepoUrl(cwd)
    if repo_url == ''
        notify.Warn('Could not detect GitHub repository from git remotes')
        return
    endif

    var url = ResolvePrUrl(cwd, repo_url, hash)
    OpenBrowser(url)
    notify.Info('Opening ' .. url)
enddef
