vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitULogGraph /^[*|/\\_. -]\+/ nextgroup=GitULogHash
syntax match GitULogHash /\x\{7,40\}\>/ contained nextgroup=GitULogRefs,GitULogSubject skipwhite
syntax match GitULogRefs / ([^)]*)/ contained nextgroup=GitULogSubject
syntax match GitULogAuthor /<[^>]\+>/
syntax match GitULogDate /(\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\})$/

highlight default link GitULogGraph Special
highlight default link GitULogHash Identifier
highlight default link GitULogRefs PreProc
highlight default link GitULogAuthor Constant
highlight default link GitULogDate Comment

b:current_syntax = 'gitu-log'
