vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUCommitHeader /^\(Commit\|Author\|Date\|Parent\):/
syntax match GitUCommitHash /\<\x\{7,40\}\>/
syntax match GitUCommitRefs / ([^)]*)$/
syntax match GitUCommitDivider /^--- Files ---$/
syntax match GitUCommitFileAdded /^A\ze\t/
syntax match GitUCommitFileModified /^M\ze\t/
syntax match GitUCommitFileDeleted /^D\ze\t/
syntax match GitUCommitFileRenamed /^[RC]\d*\ze\t/

highlight default link GitUCommitHeader Keyword
highlight default link GitUCommitHash Identifier
highlight default link GitUCommitRefs PreProc
highlight default link GitUCommitDivider Title
highlight default link GitUCommitFileAdded DiffAdd
highlight default link GitUCommitFileModified Special
highlight default link GitUCommitFileDeleted DiffDelete
highlight default link GitUCommitFileRenamed DiffChange

b:current_syntax = 'gitu-commit'
