vim9script

if exists('b:current_syntax')
    finish
endif

syntax match GitUBlameHash /\<\x\{7,40\}\>/
syntax match GitUBlameDate /^\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\}/
syntax match GitUBlameAuthor /<[^>]\+>$/

highlight default link GitUBlameHash Identifier
highlight default link GitUBlameDate Comment
highlight default link GitUBlameAuthor Type

b:current_syntax = 'gitu-blame'
