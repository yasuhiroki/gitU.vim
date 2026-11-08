vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUDiffAdded /^+\%(++\)\@!.*$/
syntax match GitUDiffRemoved /^-\%(--\)\@!.*$/
syntax match GitUDiffFile /^diff --git .*$/
syntax match GitUDiffMeta /^\(index\|new file mode\|deleted file mode\|similarity index\|rename from\|rename to\) .*$/
syntax match GitUDiffHeader /^\(---\|+++\) .*$/
syntax match GitUDiffHunk /^@@.*@@.*$/
syntax match GitUDiffCommitHeader /^\%(commit\>\|Author:\|Date:\|Merge:\)/
syntax match GitUDiffHash /\<\x\{7,40\}\>/

highlight default link GitUDiffAdded diffAdded
highlight default link GitUDiffRemoved diffRemoved
highlight default link GitUDiffChanged diffChanged
highlight default link GitUDiffFile diffFile
highlight default link GitUDiffMeta diffIndexLine
highlight default link GitUDiffHeader diffSubname
highlight default link GitUDiffHunk diffLine
highlight default link GitUDiffCommitHeader Keyword
highlight default link GitUDiffHash Identifier

highlight default link diffAdded Statement
highlight default link diffRemoved Special
highlight default link diffChanged Type
highlight default link diffFile Type
highlight default link diffLine Identifier
highlight default link diffIndexLine PreProc
highlight default link diffSubname PreProc

b:current_syntax = 'gitu-diff'
