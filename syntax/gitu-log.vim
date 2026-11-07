vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitULogGraph /^[*|/\\_. -]\+/
syntax match GitULogHash /\<\x\{7,40\}\>/
syntax match GitULogRefs /([^)]*)/
syntax match GitULogAuthor /<[^>]\+>/
syntax match GitULogDate /(\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\})$/

highlight default link GitULogGraph Delimiter
highlight default link GitULogHash Identifier
highlight default link GitULogRefs Statement
highlight default link GitULogAuthor Type
highlight default link GitULogDate Comment

b:current_syntax = 'gitu-log'
