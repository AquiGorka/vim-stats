" Basic tests for vim-stats
" Run with: vim -u NONE -S test/test_basic.vim

" Setup
set nocompatible
let &runtimepath = expand('<sfile>:p:h:h') . ',' . &runtimepath

" Use temp directory for test data
let g:vim_stats_data_dir = '/tmp/vim-stats-test-' . getpid()

" Source plugin
source <sfile>:p:h:h/plugin/vim-stats.vim
runtime autoload/vim_stats.vim

" Test helpers
let s:tests_passed = 0
let s:tests_failed = 0

function! s:Assert(condition, msg)
  if a:condition
    let s:tests_passed += 1
    echo '  PASS: ' . a:msg
  else
    let s:tests_failed += 1
    echo '  FAIL: ' . a:msg
  endif
endfunction

" Tests
echo 'Running vim-stats tests...'
echo ''

" Test 1: Plugin loads
call s:Assert(exists('g:loaded_vim_stats'), 'Plugin loaded')

" Test 2: Data dir created
call vim_stats#Init()
call s:Assert(isdirectory(g:vim_stats_data_dir), 'Data directory created')

" Test 3: Record command
call vim_stats#RecordCommand('w')
call vim_stats#RecordCommand('w')
call vim_stats#RecordCommand('q')
call s:Assert(1, 'Commands recorded without error')

" Test 4: Record mapping
call vim_stats#RecordMapping('<Space>f', 'find word')
call vim_stats#RecordMapping('S', 'save')
call s:Assert(1, 'Mappings recorded without error')

" Test 5: Record typo
call vim_stats#RecordPotentialTypo('wq', 'qw')
call s:Assert(1, 'Typo recorded without error')

" Test 6: Flush works
call vim_stats#Cleanup()
call s:Assert(filereadable(g:vim_stats_data_dir . '/sessions.jsonl'), 'Session file created')

" Test 7: JSON valid
let l:session_content = readfile(g:vim_stats_data_dir . '/sessions.jsonl')
try
  call json_decode(l:session_content[0])
  call s:Assert(1, 'Session JSON valid')
catch
  call s:Assert(0, 'Session JSON valid: ' . v:exception)
endtry

" Cleanup
call delete(g:vim_stats_data_dir, 'rf')

" Results
echo ''
echo '================================'
echo 'Tests passed: ' . s:tests_passed
echo 'Tests failed: ' . s:tests_failed
echo '================================'

if s:tests_failed > 0
  cquit
else
  echo 'All tests passed!'
  quit
endif
