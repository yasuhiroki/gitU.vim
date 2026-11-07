vim9script

import autoload 'gitu/github.vim'

def TestParseGitHubRepoUrl()
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('git@github.com:yasuhiroki/gitU.vim.git'))
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('git@github.com:yasuhiroki/gitU.vim'))
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('https://github.com/yasuhiroki/gitU.vim.git'))
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('https://github.com/yasuhiroki/gitU.vim'))
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('ssh://git@github.com/yasuhiroki/gitU.vim.git'))
    assert_equal('https://github.com/yasuhiroki/gitU.vim', github.ParseGitHubRepoUrl('git://github.com/yasuhiroki/gitU.vim.git'))

    # Non-GitHub URLs
    assert_equal('', github.ParseGitHubRepoUrl('git@gitlab.com:user/repo.git'))
    assert_equal('', github.ParseGitHubRepoUrl('https://example.com/repo.git'))
    assert_equal('', github.ParseGitHubRepoUrl(''))
enddef

def TestExtractPrNumber()
    assert_equal('123', github.ExtractPrNumber('Merge pull request #123 from user/branch'))
    assert_equal('456', github.ExtractPrNumber('feat(log): copy hash (#456)'))
    assert_equal('789', github.ExtractPrNumber("Title line (#789)\n\nDetailed commit message body"))
    assert_equal('12', github.ExtractPrNumber("Merge pull request #12\n\nBranch merge"))
    assert_equal('', github.ExtractPrNumber('regular commit without PR reference'))
enddef

def TestResolvePrUrl()
    var temp_dir = tempname() .. '_gitu_test_github'
    mkdir(temp_dir, 'p')

    system('git -C ' .. fnameescape(temp_dir) .. ' init -b main')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.name "Test"')
    system('git -C ' .. fnameescape(temp_dir) .. ' config user.email "test@example.com"')

    var file_path = temp_dir .. '/test.txt'
    writefile(['hello'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "feat: new feature (#42)"')

    var hash = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))
    var url = github.ResolvePrUrl(temp_dir, 'https://github.com/owner/repo', hash)
    assert_equal('https://github.com/owner/repo/pull/42', url)

    # Test fallback
    writefile(['world'], file_path)
    system('git -C ' .. fnameescape(temp_dir) .. ' add test.txt')
    system('git -C ' .. fnameescape(temp_dir) .. ' commit -m "chore: no pr"')
    var hash2 = trim(system('git -C ' .. fnameescape(temp_dir) .. ' rev-parse HEAD'))
    var fallback_url = github.ResolvePrUrl(temp_dir, 'https://github.com/owner/repo', hash2)
    # If gh finds nothing or in non-gh repo, fallback to search URL
    assert_true(stridx(fallback_url, 'https://github.com/owner/repo/pulls?q=is%3Apr+') == 0)

    delete(temp_dir, 'rf')
enddef

def RunAll()
    TestParseGitHubRepoUrl()
    TestExtractPrNumber()
    TestResolvePrUrl()

    var errors = v:errors
    if len(errors) > 0
        for err in errors
            echomsg err
        endfor
        cquit!
    else
        echomsg 'All github tests passed!'
        qall!
    endif
enddef

RunAll()
