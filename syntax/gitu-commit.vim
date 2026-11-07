vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUCommitHeader /^\(Commit\|Author\|Date\|Parent\):/
syntax match GitUCommitHash /\<\x\{7,40\}\>/
syntax match GitUCommitRefs / ([^)]*)$/
syntax match GitUCommitDivider /^--- Files ---$/

syntax match GitUCommitFileAdded /^A\t.*/ contains=GitUCommitStatusAdded
syntax match GitUCommitFileModified /^M\t.*/ contains=GitUCommitStatusModified
syntax match GitUCommitFileDeleted /^D\t.*/ contains=GitUCommitStatusDeleted
syntax match GitUCommitFileRenamed /^[RC]\d*\t.*/ contains=GitUCommitStatusRenamed

syntax match GitUCommitStatusAdded /^A\ze\t/ contained
syntax match GitUCommitStatusModified /^M\ze\t/ contained
syntax match GitUCommitStatusDeleted /^D\ze\t/ contained
syntax match GitUCommitStatusRenamed /^[RC]\d*\ze\t/ contained

highlight default link GitUCommitHeader Keyword
highlight default link GitUCommitHash Identifier
highlight default link GitUCommitRefs Statement
highlight default link GitUCommitDivider Title
highlight default link GitUCommitStatusAdded diffAdded
highlight default link GitUCommitStatusModified diffChanged
highlight default link GitUCommitStatusDeleted diffRemoved
highlight default link GitUCommitStatusRenamed diffChanged
highlight default link GitUCommitFileAdded Directory
highlight default link GitUCommitFileModified Directory
highlight default link GitUCommitFileDeleted Directory
highlight default link GitUCommitFileRenamed Directory

highlight default link diffAdded Statement
highlight default link diffRemoved Special
highlight default link diffChanged Type

b:current_syntax = 'gitu-commit'
