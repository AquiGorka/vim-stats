" vim-stats-user-mappings.vim
" Custom mapping tracking for AquiGorka's vimrc
" This file is loaded after all plugins, so it can safely override mappings

if !exists('g:loaded_vim_stats') || !g:vim_stats_enabled
  finish
endif

" Helper function to create a tracked mapping
" Uses expression mappings for zero overhead
function! s:TrackedMap(mode, lhs, rhs, desc) abort
  " Store original mapping info for unused detection
  if !exists('g:vim_stats_user_mappings')
    let g:vim_stats_user_mappings = {}
  endif
  let g:vim_stats_user_mappings[a:lhs] = {'mode': a:mode, 'desc': a:desc, 'rhs': a:rhs}
endfunction

" Register your custom mappings for tracking
" These don't override your mappings, just register them for unused detection

" Get leader (assuming comma from your vimrc)
let s:leader = get(g:, 'mapleader', ',')

" Tab navigation
call s:TrackedMap('n', '<C-l>', ':tabnew', 'new tab')
call s:TrackedMap('n', '<C-d><Left>', ':tabprevious', 'prev tab')
call s:TrackedMap('n', '<C-d><Right>', ':tabnext', 'next tab')
call s:TrackedMap('n', '<C-e><Left>', ':-tabmove', 'move tab left')
call s:TrackedMap('n', '<C-e><Right>', ':+tabmove', 'move tab right')

" Search/Replace
call s:TrackedMap('n', 'R', 'interactive replace', 'find/replace')
call s:TrackedMap('n', '<Space>s', '/', 'start search')
call s:TrackedMap('n', '<Space>m', ':nohlsearch', 'clear highlight')
call s:TrackedMap('n', '<Space>r', ':%s/word//g', 'replace word')
call s:TrackedMap('n', '<Space>f', '*', 'find word')

" File operations
call s:TrackedMap('n', 'S', ':update', 'save file')
call s:TrackedMap('n', 'Q', ':q', 'quit')
call s:TrackedMap('n', '<Space>d', 'yyp', 'duplicate line')
call s:TrackedMap('n', 'ft', ':retab', 'remove tabs')

" Insert mode
call s:TrackedMap('i', s:leader.s:leader, '<Esc>', 'exit insert')
call s:TrackedMap('i', '<Space><BS>', '<C-W>', 'delete word')

" Buffers
call s:TrackedMap('n', 'ss<Left>', ':bprevious', 'prev buffer')
call s:TrackedMap('n', 'ss<Right>', ':bnext', 'next buffer')
call s:TrackedMap('n', 'ss<Space>', ':tab sball', 'buffers to tabs')

" NERDTree
call s:TrackedMap('n', '<C-o>', ':NERDTreeToggle', 'toggle NERDTree')
call s:TrackedMap('n', 'M', ':NERDTreeFind', 'NERDTree focus')

" Line movement
call s:TrackedMap('n', 'fj', ':move +1', 'move line down')
call s:TrackedMap('n', 'fk', ':move -2', 'move line up')

" Git
call s:TrackedMap('n', s:leader.'l', ':Git log -p', 'git log')
call s:TrackedMap('n', s:leader.'r', ':source vimrc', 'reload vimrc')
call s:TrackedMap('n', 'zk', '[c', 'prev git hunk')
call s:TrackedMap('n', 'zj', ']c', 'next git hunk')

" Linting
call s:TrackedMap('n', '<Space>bb', ':!ruff check', 'ruff check')
call s:TrackedMap('n', '<Space>mm', ':!ruff format', 'ruff format')

" Now create actual tracked versions by wrapping the execution
" This is optional - only enable if you want per-use tracking

" Uncomment to enable per-use tracking (adds minimal overhead):
" nnoremap <silent> S :call vim_stats#RecordMapping('S', 'save')<CR>:update<CR>
" nnoremap <silent> Q :call vim_stats#RecordMapping('Q', 'quit')<CR>:q<CR>
" etc.

" Alternative: Track via CmdlineEnter for Ex commands
" This catches all : commands without per-mapping overhead
augroup vim_stats_user
  autocmd!
  " Already handled in main plugin via CmdlineLeave
augroup END
