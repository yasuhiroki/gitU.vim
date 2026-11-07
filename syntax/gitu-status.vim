vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUStatusBranch /^Branch:.*$/
syntax match GitUStatusHeaderStaged /^Changes to be committed:$/
syntax match GitUStatusHeaderUnstaged /^Changes not staged for commit:$/
syntax match GitUStatusHeaderUntracked /^Untracked files:$/
syntax match GitUStatusClean /^nothing to commit.*$/

syntax match GitUStatusFileAdded /^  A\s\+.*/ contains=GitUStatusSymbolAdded
syntax match GitUStatusFileModified /^  M\s\+.*/ contains=GitUStatusSymbolModified
syntax match GitUStatusFileDeleted /^  D\s\+.*/ contains=GitUStatusSymbolDeleted
syntax match GitUStatusFileRenamed /^  R\s\+.*/ contains=GitUStatusSymbolRenamed
syntax match GitUStatusFileUntracked /^  ?\s\+.*/ contains=GitUStatusSymbolUntracked

syntax match GitUStatusSymbolAdded /^  A\ze\s/ contained
syntax match GitUStatusSymbolModified /^  M\ze\s/ contained
syntax match GitUStatusSymbolDeleted /^  D\ze\s/ contained
syntax match GitUStatusSymbolRenamed /^  R\ze\s/ contained
syntax match GitUStatusSymbolUntracked /^  ?\ze\s/ contained

highlight default link GitUStatusBranch Title
highlight default link GitUStatusHeaderStaged diffAdded
highlight default link GitUStatusHeaderUnstaged diffRemoved
highlight default link GitUStatusHeaderUntracked diffChanged
highlight default link GitUStatusClean Comment

highlight default link GitUStatusSymbolAdded diffAdded
highlight default link GitUStatusSymbolModified diffChanged
highlight default link GitUStatusSymbolDeleted diffRemoved
highlight default link GitUStatusSymbolRenamed diffChanged
highlight default link GitUStatusSymbolUntracked PreProc

highlight default link GitUStatusFileAdded Directory
highlight default link GitUStatusFileModified Directory
highlight default link GitUStatusFileDeleted Directory
highlight default link GitUStatusFileRenamed Directory
highlight default link GitUStatusFileUntracked Directory

highlight default link diffAdded Statement
highlight default link diffRemoved Special
highlight default link diffChanged Type

b:current_syntax = 'gitu-status'
