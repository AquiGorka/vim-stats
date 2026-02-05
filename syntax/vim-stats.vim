" Syntax highlighting for vim-stats output buffers

if exists('b:current_syntax')
  finish
endif

" Headers
syntax match vimStatsHeader /^═.*═$/
syntax match vimStatsSectionHeader /^──.*──$/
syntax match vimStatsTitle /VIM USAGE STATISTICS\|DETECTED TYPOS\|UNUSED MAPPINGS\|MAPPING USAGE\|COMMAND LINE USAGE/

" Numbers (counts)
syntax match vimStatsCount /^\s*\d\+\s/ contained
syntax match vimStatsLine /^\s*\d\+\s.*$/ contains=vimStatsCount

" Mappings
syntax match vimStatsMapping /<[^>]\+>/ contained containedin=vimStatsLine
syntax match vimStatsMappingMode /\[\w\]/ contained containedin=vimStatsLine

" Tips
syntax match vimStatsTip /TIP:.*/

" Commands info
syntax match vimStatsCommands /Commands:.*/

" Arrows in typo display
syntax match vimStatsArrow / -> /

" Highlights
highlight default link vimStatsHeader Title
highlight default link vimStatsSectionHeader Statement
highlight default link vimStatsTitle Special
highlight default link vimStatsCount Number
highlight default link vimStatsMapping Identifier
highlight default link vimStatsMappingMode Type
highlight default link vimStatsTip Comment
highlight default link vimStatsCommands Comment
highlight default link vimStatsArrow Operator

let b:current_syntax = 'vim-stats'
