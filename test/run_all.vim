vim9script

var repo_root = fnameescape(getcwd())
var test_files = glob('test/**/*_test.vim', 1, 1)
var total = len(test_files)
var failed = 0

for file in test_files
    var out = system('vim -u NONE -es -N --cmd "set rtp^=' .. repo_root .. '" -S ' .. file)
    if v:shell_error != 0
        failed += 1
        echomsg 'FAILED: ' .. file
        if out != ''
            echomsg out
        endif
    else
        echomsg 'PASSED: ' .. file
    endif
endfor

if failed > 0
    echomsg printf('Tests failed: %d / %d', failed, total)
    cquit!
else
    echomsg printf('All %d test suites passed!', total)
    qall!
endif
