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

highlight default link GitUDiffAdded DiffAdd
highlight default link GitUDiffRemoved DiffDelete
highlight default link GitUDiffFile Title
highlight default link GitUDiffMeta Comment
highlight default link GitUDiffHeader PreProc
highlight default link GitUDiffHunk Special

b:current_syntax = 'gitu-diff'
