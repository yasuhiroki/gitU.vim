vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUGhNumber /^#\d\+/
syntax match GitUGhLabels /\[[^\]]\+\]/
syntax match GitUGhStateOpen /\[OPEN\]/
syntax match GitUGhStateClosed /\[CLOSED\]/
syntax match GitUGhStateMerged /\[MERGED\]/
syntax match GitUGhStateDraft /\[DRAFT\]/
syntax match GitUGhBranch /([^()]* <- [^()]*)/
syntax match GitUGhAuthor /(@[^()]\+)/
syntax match GitUGhMeta /(\d\+ items)/

highlight default link GitUGhNumber Identifier
highlight default link GitUGhLabels Statement
highlight default link GitUGhStateOpen diffAdded
highlight default link GitUGhStateClosed diffRemoved
highlight default link GitUGhStateMerged Constant
highlight default link GitUGhStateDraft Comment
highlight default link GitUGhBranch PreProc
highlight default link GitUGhAuthor Type
highlight default link GitUGhMeta Comment

highlight default link diffAdded Statement
highlight default link diffRemoved Special

b:current_syntax = 'gitu-gh-list'
