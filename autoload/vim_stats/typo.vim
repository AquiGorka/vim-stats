" vim_stats/typo.vim - Typo detection system
" Detects potential typos by analyzing failed key sequences

" State for typo detection
let s:last_cmdline = ''
let s:failed_commands = []
let s:key_history = []
let s:max_history = 50

" Called when a command fails (E492 Unknown command, etc)
function! vim_stats#typo#OnCommandError(cmd) abort
  call add(s:failed_commands, {
        \ 'time': localtime(),
        \ 'cmd': a:cmd,
        \ })

  " Keep only recent failures
  if len(s:failed_commands) > 20
    let s:failed_commands = s:failed_commands[-20:]
  endif
endfunction

" Called when a command succeeds
function! vim_stats#typo#OnCommandSuccess(cmd) abort
  " Check if this success follows a similar failure
  for failed in s:failed_commands
    if (localtime() - failed.time) < 5  " Within 5 seconds
      let l:similarity = s:CalculateSimilarity(failed.cmd, a:cmd)
      if l:similarity > 0.7  " 70% similar
        call vim_stats#RecordPotentialTypo(failed.cmd, a:cmd)
      endif
    endif
  endfor
endfunction

" Track normal mode key presses for pattern detection
function! vim_stats#typo#RecordKey(key) abort
  call add(s:key_history, {
        \ 'time': reltime(),
        \ 'key': a:key,
        \ })

  " Trim history
  if len(s:key_history) > s:max_history
    let s:key_history = s:key_history[-s:max_history:]
  endif
endfunction

" Analyze recent key history for typo patterns
function! vim_stats#typo#AnalyzePatterns() abort
  let l:typos = []

  " Look for patterns: rapid sequence -> pause -> similar sequence
  let i = 0
  while i < len(s:key_history) - 1
    let l:entry = s:key_history[i]
    let l:next = s:key_history[i + 1]

    " Check for timing pattern indicating correction
    " (Implementation depends on actual usage patterns)

    let i += 1
  endwhile

  return l:typos
endfunction

" Calculate similarity between two strings (Levenshtein-based)
function! s:CalculateSimilarity(s1, s2) abort
  let l:len1 = len(a:s1)
  let l:len2 = len(a:s2)

  if l:len1 == 0 || l:len2 == 0
    return 0.0
  endif

  " Simple similarity: common prefix + suffix
  let l:common = 0
  let l:min_len = min([l:len1, l:len2])

  " Count matching characters
  for i in range(l:min_len)
    if a:s1[i] ==# a:s2[i]
      let l:common += 1
    endif
  endfor

  " Also check from end
  for i in range(1, l:min_len)
    if a:s1[l:len1 - i] ==# a:s2[l:len2 - i]
      let l:common += 1
    endif
  endfor

  return (l:common * 1.0) / (l:len1 + l:len2)
endfunction

" Detect potential typos from cmdline history
function! vim_stats#typo#ScanCmdlineHistory() abort
  " Get command history
  let l:history = []
  for i in range(1, histnr(':'))
    let l:cmd = histget(':', i)
    if l:cmd != ''
      call add(l:history, l:cmd)
    endif
  endfor

  " Look for similar consecutive commands (potential typo + correction)
  let l:typos = {}
  let i = 0
  while i < len(l:history) - 1
    let l:cmd1 = l:history[i]
    let l:cmd2 = l:history[i + 1]

    " Check if commands are similar but not identical
    if l:cmd1 != l:cmd2
      let l:sim = s:CalculateSimilarity(l:cmd1, l:cmd2)
      if l:sim > 0.7 && l:sim < 1.0
        " Check if first one looks like a typo (shorter or has typo patterns)
        let l:key = l:cmd1 . ' -> ' . l:cmd2
        let l:typos[l:key] = get(l:typos, l:key, 0) + 1
      endif
    endif

    let i += 1
  endwhile

  return l:typos
endfunction

" Hook into Vim's error messages for command failures
function! vim_stats#typo#SetupErrorTracking() abort
  " Use autocmd to catch command errors
  augroup vim_stats_typo
    autocmd!
    " Track command line changes
    autocmd CmdlineLeave : call s:OnCmdlineLeave()
  augroup END
endfunction

let s:last_cmdline_content = ''

function! s:OnCmdlineLeave() abort
  let l:cmd = getcmdline()
  if empty(l:cmd)
    return
  endif

  " Store for comparison
  if !empty(s:last_cmdline_content)
    let l:sim = s:CalculateSimilarity(s:last_cmdline_content, l:cmd)
    if l:sim > 0.6 && l:sim < 0.95 && len(l:cmd) > 2
      " Likely a correction
      call vim_stats#RecordPotentialTypo(s:last_cmdline_content, l:cmd)
    endif
  endif

  let s:last_cmdline_content = l:cmd
endfunction

" Detect typo patterns in normal mode
" Called periodically or on specific events
function! vim_stats#typo#DetectNormalModeTypos() abort
  " This function analyzes patterns like:
  " - dww (deleted word, then w to move - likely meant dw then w)
  " - ciw<Esc>i (change word, exit, enter insert - likely meant ciw directly)
  " etc.

  " Implementation would track actual key sequences and look for
  " undo patterns or repeated similar sequences
endfunction
