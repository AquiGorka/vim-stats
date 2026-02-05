" Example: How to add tracking to your existing mappings
" Copy the relevant parts to your vimrc
"
" There are two approaches:
"
" 1. LIGHTWEIGHT (recommended): Just register mappings for unused detection
"    The plugin tracks Ex commands automatically. This approach lets you
"    see which of your mappings are unused without any runtime overhead.
"
" 2. DETAILED: Wrap each mapping to track individual usage
"    Adds minimal overhead but gives per-mapping usage counts.

" ============================================================================
" APPROACH 1: Register for unused detection (zero overhead)
" ============================================================================
" Add this AFTER your mapping definitions:

if exists('*vim_stats#RecordMapping')
  " Register your mappings - they'll appear in :VimStatsUnused if not used
  let g:vim_stats_registered_mappings = {
        \ 'S': 'save file',
        \ 'Q': 'quit',
        \ 'R': 'find/replace',
        \ '<C-l>': 'new tab',
        \ '<C-d><Left>': 'prev tab',
        \ '<C-d><Right>': 'next tab',
        \ '<Space>s': 'start search',
        \ '<Space>m': 'clear highlight',
        \ '<Space>r': 'replace word',
        \ '<Space>f': 'find word',
        \ '<Space>d': 'duplicate line',
        \ 'ft': 'remove tabs',
        \ 'fj': 'move line down',
        \ 'fk': 'move line up',
        \ 'ss<Left>': 'prev buffer',
        \ 'ss<Right>': 'next buffer',
        \ '<C-o>': 'NERDTree toggle',
        \ 'M': 'NERDTree focus',
        \ ',l': 'git log',
        \ ',r': 'reload vimrc',
        \ 'zk': 'prev hunk',
        \ 'zj': 'next hunk',
        \ '<Space>bb': 'ruff check',
        \ '<Space>mm': 'ruff format',
        \ }
endif

" ============================================================================
" APPROACH 2: Wrapped mappings for per-use tracking
" ============================================================================
" Replace your existing mappings with these tracked versions.
" The overhead is minimal (one dict lookup + increment per use).

" Helper function to create tracked mappings
function! s:Track(key, desc)
  if exists('*vim_stats#RecordMapping')
    call vim_stats#RecordMapping(a:key, a:desc)
  endif
endfunction

" File operations
nnoremap <silent> S :call <SID>Track('S', 'save')<CR>:update<CR>
nnoremap <silent> Q :call <SID>Track('Q', 'quit')<CR>:q<CR>

" Tab navigation
nnoremap <silent> <C-l> :call <SID>Track('<C-l>', 'new tab')<CR>:tabnew<CR>
nnoremap <silent> <C-d><Left> :call <SID>Track('<C-d><Left>', 'prev tab')<CR>:tabprevious<CR>
nnoremap <silent> <C-d><Right> :call <SID>Track('<C-d><Right>', 'next tab')<CR>:tabnext<CR>

" Search
nnoremap <silent> <Space>s :call <SID>Track('<Space>s', 'search')<CR>/
nnoremap <silent> <Space>m :call <SID>Track('<Space>m', 'clear hl')<CR>:nohlsearch<CR>
nnoremap <silent> <Space>f :call <SID>Track('<Space>f', 'find word')<CR>*

" Line operations
nnoremap <silent> <Space>d :call <SID>Track('<Space>d>', 'dup line')<CR>yyp
nnoremap <silent> fj :call <SID>Track('fj', 'line down')<CR>:move .+1<CR>
nnoremap <silent> fk :call <SID>Track('fk', 'line up')<CR>:move .-2<CR>

" Buffers
nnoremap <silent> ss<Left> :call <SID>Track('ss<Left>', 'prev buf')<CR>:bprevious<CR>
nnoremap <silent> ss<Right> :call <SID>Track('ss<Right>', 'next buf')<CR>:bnext<CR>

" ============================================================================
" APPROACH 3: Expression mappings (most elegant, zero overhead)
" ============================================================================
" Uses vim's expression mappings - the tracking runs in a timer
" so there's literally no blocking.

" Note: This only works for simple mappings, not complex ones

" Example:
" nnoremap <expr> S vim_stats#track#Expr('S', 'save') . ':update<CR>'

" For your workflow, Approach 1 is recommended because:
" - Zero runtime overhead
" - Ex commands are tracked automatically anyway
" - You still get unused mapping detection
