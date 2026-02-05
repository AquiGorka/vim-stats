" vim_stats/track.vim - Lightweight mapping tracking
" Creates tracking wrappers for custom mappings

" Generate tracking wrapper for a mapping
" This is called once at startup, not during normal use
function! vim_stats#track#WrapMapping(mode, lhs, rhs, desc) abort
  " Create a unique function name
  let l:func_name = 'VimStatsTrack_' . s:SanitizeName(a:lhs)

  " Create the tracking function
  execute 'function! ' . l:func_name . '() abort'
        \ . "\n  call vim_stats#RecordMapping(" . string(a:lhs) . ", " . string(a:desc) . ")"
        \ . "\n  return " . string(a:rhs)
        \ . "\nendfunction"

  " Create the new mapping that calls our tracker
  if a:mode ==# 'n'
    execute 'nnoremap <silent> ' . a:lhs . ' :<C-U>call vim_stats#RecordMapping(' . string(a:lhs) . ',' . string(a:desc) . ')<CR>' . a:rhs
  elseif a:mode ==# 'i'
    execute 'inoremap <silent> ' . a:lhs . ' <C-O>:call vim_stats#RecordMapping(' . string(a:lhs) . ',' . string(a:desc) . ')<CR>' . a:rhs
  elseif a:mode ==# 'v'
    execute 'vnoremap <silent> ' . a:lhs . ' :<C-U>call vim_stats#RecordMapping(' . string(a:lhs) . ',' . string(a:desc) . ')<CR>gv' . a:rhs
  endif
endfunction

" Sanitize mapping name for use as function name
function! s:SanitizeName(name) abort
  let l:result = a:name
  let l:result = substitute(l:result, '<', '_lt_', 'g')
  let l:result = substitute(l:result, '>', '_gt_', 'g')
  let l:result = substitute(l:result, '-', '_', 'g')
  let l:result = substitute(l:result, ' ', '_sp_', 'g')
  let l:result = substitute(l:result, '[^a-zA-Z0-9_]', '_', 'g')
  return l:result
endfunction

" Setup tracking for standard vim motions and operators
" This uses feedkeys to track without interrupting normal flow
function! vim_stats#track#SetupMotionTracking() abort
  " Track common motions
  let l:motions = ['w', 'W', 'b', 'B', 'e', 'E', '0', '$', '^', 'gg', 'G',
        \ '{', '}', '(', ')', '[[', ']]', 'H', 'M', 'L',
        \ 'f', 'F', 't', 'T', ';', ',', '%']

  for motion in l:motions
    call s:TrackMotion(motion)
  endfor

  " Track common operators
  let l:operators = ['d', 'c', 'y', '>', '<', '=', 'gq', 'gw', 'g~', 'gu', 'gU']

  for op in l:operators
    call s:TrackOperator(op)
  endfor
endfunction

" Create motion tracking (very lightweight)
function! s:TrackMotion(motion) abort
  " We use expression mappings for zero-overhead tracking
  " The expression is evaluated but returns the original key
  execute 'nnoremap <expr> ' . a:motion . ' <SID>TrackAndReturn(' . string(a:motion) . ')'
endfunction

function! s:TrackOperator(op) abort
  execute 'nnoremap <expr> ' . a:op . ' <SID>TrackAndReturn(' . string(a:op) . ')'
endfunction

" Minimal tracking function - just increments counter and returns key
let s:motion_counts = {}

function! s:TrackAndReturn(key) abort
  let s:motion_counts[a:key] = get(s:motion_counts, a:key, 0) + 1
  return a:key
endfunction

" Flush motion counts periodically (called by timer)
function! vim_stats#track#FlushMotions() abort
  if empty(s:motion_counts)
    return
  endif

  for [motion, count] in items(s:motion_counts)
    call vim_stats#RecordMapping(motion, 'motion')
  endfor
  let s:motion_counts = {}
endfunction

" Failed key sequence detection
" Uses getchar() with timeout to detect failed sequences
let s:pending_keys = ''
let s:last_successful = ''

function! vim_stats#track#OnKeyPress() abort
  " This is called infrequently via CursorHold
  " to check for patterns in failed sequences
endfunction

" Track specific user mappings from vimrc
" Call this function in your vimrc after defining mappings
function! vim_stats#track#TrackUserMappings() abort
  " Get leader key
  let l:leader = exists('g:mapleader') ? g:mapleader : '\'

  " Define the mappings to track based on AquiGorka's vimrc
  " Format: [mode, lhs, description]
  let l:user_mappings = [
        \ ['n', '<C-l>', 'new tab'],
        \ ['n', '<C-d><left>', 'prev tab'],
        \ ['n', '<C-d><right>', 'next tab'],
        \ ['n', '<C-e><left>', 'move tab left'],
        \ ['n', '<C-e><right>', 'move tab right'],
        \ ['n', 'R', 'find/replace interactive'],
        \ ['n', '<space>s', 'start search'],
        \ ['n', '<space>m', 'clear search highlight'],
        \ ['n', '<space>r', 'replace word globally'],
        \ ['n', '<space>f', 'find word under cursor'],
        \ ['n', 'S', 'save file'],
        \ ['n', 'Q', 'quit'],
        \ ['n', '<space>d', 'duplicate line'],
        \ ['n', 'ft', 'remove tabs'],
        \ ['i', l:leader . l:leader, 'exit insert mode'],
        \ ['i', '<space><BS>', 'delete word'],
        \ ['n', 'ss<left>', 'prev buffer'],
        \ ['n', 'ss<right>', 'next buffer'],
        \ ['n', 'ss<space>', 'buffer in tab'],
        \ ['n', '<C-o>', 'toggle NERDTree'],
        \ ['n', 'fj', 'move line down'],
        \ ['n', 'fk', 'move line up'],
        \ ['n', l:leader . 'l', 'git log'],
        \ ['n', l:leader . 'r', 'reload vimrc'],
        \ ['n', 'zk', 'prev git hunk'],
        \ ['n', 'zj', 'next git hunk'],
        \ ['n', 'M', 'NERDTree focus'],
        \ ['n', '<space>bb', 'ruff check'],
        \ ['n', '<space>mm', 'ruff format'],
        \ ]

  " Store for unused mapping detection
  let g:vim_stats_tracked_mappings = l:user_mappings
endfunction

" Expression mapping for tracking without overhead
" Returns the original keys while recording asynchronously
function! vim_stats#track#Expr(keys, desc) abort
  " Use timer to record asynchronously (no blocking)
  if has('timers')
    call timer_start(0, {-> vim_stats#RecordMapping(a:keys, a:desc)})
  else
    call vim_stats#RecordMapping(a:keys, a:desc)
  endif
  return a:keys
endfunction
