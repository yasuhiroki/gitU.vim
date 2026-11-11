vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUGhHeader /^\(Issue\|PR\|Project\|Item\|Title\|Author\|Branch\|Review\|Assignees\|Labels\|Milestone\|Created\|Updated\|URL\|Owner\|Items\|Description\|Type\|Status\|Repository\):/
syntax match GitUGhDivider /^--- .* ---$/
syntax match GitUGhNumber /#\d\+/
syntax match GitUGhStateOpen /\[OPEN\]/
syntax match GitUGhStateClosed /\[CLOSED\]/
syntax match GitUGhStateMerged /\[MERGED\]/
syntax match GitUGhStateDraft /\[DRAFT\]/
syntax match GitUGhAuthor /@[A-Za-z0-9_.-]\+/
syntax match GitUGhFileModified /^M\t.*/ contains=GitUGhStatusModified
syntax match GitUGhStatusModified /^M\ze\t/ contained
syntax match GitUGhItemStatus /^\s\+\[[^\]]\+\]/

highlight default link GitUGhHeader Keyword
highlight default link GitUGhDivider Title
highlight default link GitUGhNumber Identifier
highlight default link GitUGhStateOpen diffAdded
highlight default link GitUGhStateClosed diffRemoved
highlight default link GitUGhStateMerged Constant
highlight default link GitUGhStateDraft Comment
highlight default link GitUGhAuthor Type
highlight default link GitUGhFileModified Directory
highlight default link GitUGhStatusModified diffChanged
highlight default link GitUGhItemStatus Statement

highlight default link diffAdded Statement
highlight default link diffRemoved Special
highlight default link diffChanged Type

b:current_syntax = 'gitu-gh-detail'
