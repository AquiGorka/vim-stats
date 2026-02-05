" vim_stats.vim - Autoload functions for vim-stats
" This file is loaded on-demand to minimize startup impact

" Internal state
let s:key_buffer = []
let s:command_counts = {}
let s:mapping_counts = {}
let s:potential_typos = []
let s:session_start = localtime()
let s:flush_timer = -1
let s:last_failed_seq = ''
let s:last_failed_time = 0

" ============================================================================
" Core tracking functions
" ============================================================================

" Ensure data directory exists
function! s:EnsureDataDir() abort
  if !isdirectory(g:vim_stats_data_dir)
    call mkdir(g:vim_stats_data_dir, 'p')
  endif
endfunction

" Get today's date for file naming
function! s:Today() abort
  return strftime('%Y-%m-%d')
endfunction

" Async file append (non-blocking)
function! s:AsyncAppend(file, lines) abort
  if empty(a:lines)
    return
  endif

  let l:content = join(a:lines, "\n") . "\n"

  if has('nvim')
    " Neovim: use jobstart
    let l:job = jobstart(['sh', '-c', 'cat >> ' . shellescape(a:file)], {'stdin': 'pipe'})
    call chansend(l:job, l:content)
    call chanclose(l:job, 'stdin')
  elseif has('job') && has('channel')
    " Vim 8+: use job_start
    let l:cmd = ['sh', '-c', 'cat >> ' . shellescape(a:file)]
    let l:job = job_start(l:cmd, {'in_mode': 'raw'})
    let l:channel = job_getchannel(l:job)
    call ch_sendraw(l:channel, l:content)
    call ch_close_in(l:channel)
  else
    " Fallback: synchronous write (still fast for small appends)
    call writefile(split(l:content, "\n"), a:file, 'a')
  endif
endfunction

" Record a keystroke/command
function! vim_stats#RecordKey(key, context) abort
  if !g:vim_stats_enabled
    return
  endif

  let l:entry = {
        \ 'time': localtime(),
        \ 'key': a:key,
        \ 'context': a:context,
        \ 'mode': mode(),
        \ }
  call add(s:key_buffer, l:entry)

  " Flush if buffer is full
  if len(s:key_buffer) >= g:vim_stats_max_buffer_size
    call s:FlushBufferInternal()
  endif
endfunction

" Record command execution
function! vim_stats#RecordCommand(cmd) abort
  if !g:vim_stats_enabled
    return
  endif

  let l:cmd = a:cmd
  if empty(l:cmd)
    return
  endif
  if !has_key(s:command_counts, l:cmd)
    let s:command_counts[l:cmd] = 0
  endif
  let s:command_counts[l:cmd] += 1
endfunction

" Record mapping usage
function! vim_stats#RecordMapping(mapping, description) abort
  if !g:vim_stats_enabled
    return
  endif

  let l:key = a:mapping
  if !has_key(s:mapping_counts, l:key)
    let s:mapping_counts[l:key] = {'count': 0, 'desc': a:description}
  endif
  let s:mapping_counts[l:key].count += 1
endfunction

" Typo detection: track sequences that fail then succeed with minor changes
function! vim_stats#RecordPotentialTypo(failed, succeeded) abort
  if !g:vim_stats_enabled
    return
  endif

  call add(s:potential_typos, {
        \ 'time': localtime(),
        \ 'failed': a:failed,
        \ 'succeeded': a:succeeded,
        \ })
endfunction

" Track failed key sequences (for typo detection)
function! vim_stats#TrackKeySequence(seq, succeeded) abort
  if !g:vim_stats_enabled
    return
  endif

  let l:now = localtime()

  if !a:succeeded
    let s:last_failed_seq = a:seq
    let s:last_failed_time = l:now
  else
    " Check if this success follows a recent failure with similar sequence
    if s:last_failed_seq != '' && (l:now - s:last_failed_time) < 3
      " Calculate similarity (simple check)
      let l:failed_len = len(s:last_failed_seq)
      let l:success_len = len(a:seq)
      if abs(l:failed_len - l:success_len) <= 2
        " Likely a typo correction
        call vim_stats#RecordPotentialTypo(s:last_failed_seq, a:seq)
      endif
    endif
    let s:last_failed_seq = ''
  endif
endfunction

" ============================================================================
" Buffer flush functions
" ============================================================================

" Internal flush (script-local)
function! s:FlushBufferInternal() abort
  call s:EnsureDataDir()

  let l:today = s:Today()

  " Flush key buffer
  if !empty(s:key_buffer)
    let l:lines = []
    for entry in s:key_buffer
      call add(l:lines, json_encode(entry))
    endfor
    call s:AsyncAppend(g:vim_stats_data_dir . '/keys-' . l:today . '.jsonl', l:lines)
    let s:key_buffer = []
  endif

  " Flush command counts
  if !empty(s:command_counts)
    let l:cmd_file = g:vim_stats_data_dir . '/commands-' . l:today . '.json'
    let l:existing = {}
    if filereadable(l:cmd_file)
      try
        let l:existing = json_decode(join(readfile(l:cmd_file), ''))
      catch
        let l:existing = {}
      endtry
    endif
    for [cmd, cnt] in items(s:command_counts)
      let l:existing[cmd] = get(l:existing, cmd, 0) + cnt
    endfor
    call writefile([json_encode(l:existing)], l:cmd_file)
    let s:command_counts = {}
  endif

  " Flush mapping counts
  if !empty(s:mapping_counts)
    let l:map_file = g:vim_stats_data_dir . '/mappings-' . l:today . '.json'
    let l:existing = {}
    if filereadable(l:map_file)
      try
        let l:existing = json_decode(join(readfile(l:map_file), ''))
      catch
        let l:existing = {}
      endtry
    endif
    for [mapping, data] in items(s:mapping_counts)
      if has_key(l:existing, mapping)
        let l:existing[mapping].count += data.count
      else
        let l:existing[mapping] = data
      endif
    endfor
    call writefile([json_encode(l:existing)], l:map_file)
    let s:mapping_counts = {}
  endif

  " Flush typos
  if !empty(s:potential_typos)
    let l:lines = []
    for typo in s:potential_typos
      call add(l:lines, json_encode(typo))
    endfor
    call s:AsyncAppend(g:vim_stats_data_dir . '/typos-' . l:today . '.jsonl', l:lines)
    let s:potential_typos = []
  endif
endfunction

" Public flush function
function! vim_stats#FlushBuffer() abort
  call s:FlushBufferInternal()
endfunction

" Timer callback for periodic flush
function! s:FlushTimerCallback(timer) abort
  call s:FlushBufferInternal()
endfunction

" Start the flush timer
function! s:StartFlushTimer() abort
  if s:flush_timer != -1
    return
  endif

  if has('timers')
    let s:flush_timer = timer_start(g:vim_stats_flush_interval, function('s:FlushTimerCallback'), {'repeat': -1})
  endif
endfunction

" Stop the flush timer (public)
function! vim_stats#StopTimer() abort
  if s:flush_timer != -1 && has('timers')
    call timer_stop(s:flush_timer)
    let s:flush_timer = -1
  endif
endfunction

" ============================================================================
" Init and cleanup
" ============================================================================

" Initialize tracking
function! vim_stats#Init() abort
  if !g:vim_stats_enabled
    return
  endif

  let s:session_start = localtime()
  call s:EnsureDataDir()
  call s:StartFlushTimer()

  " Record session start
  let l:session_file = g:vim_stats_data_dir . '/sessions.jsonl'
  call s:AsyncAppend(l:session_file, [json_encode({
        \ 'event': 'start',
        \ 'time': s:session_start,
        \ 'cwd': getcwd(),
        \ })])
endfunction

" Cleanup on exit
function! vim_stats#Cleanup() abort
  call vim_stats#StopTimer()
  call s:FlushBufferInternal()

  " Record session end
  let l:session_file = g:vim_stats_data_dir . '/sessions.jsonl'
  let l:duration = localtime() - s:session_start
  call writefile([json_encode({
        \ 'event': 'end',
        \ 'time': localtime(),
        \ 'duration': l:duration,
        \ })], l:session_file, 'a')
endfunction

" ============================================================================
" Stats display functions
" ============================================================================

" Show general statistics
function! vim_stats#ShowStats(days) abort
  let l:days = empty(a:days) ? 7 : str2nr(a:days)
  let l:data_dir = g:vim_stats_data_dir

  if !isdirectory(l:data_dir)
    echo "No stats data found. Start using Vim to collect data!"
    return
  endif

  " Gather data from the last N days
  let l:all_commands = {}
  let l:all_mappings = {}
  let l:total_sessions = 0
  let l:total_duration = 0

  for i in range(l:days)
    let l:date = strftime('%Y-%m-%d', localtime() - (i * 86400))

    " Load commands
    let l:cmd_file = l:data_dir . '/commands-' . l:date . '.json'
    if filereadable(l:cmd_file)
      try
        let l:cmds = json_decode(join(readfile(l:cmd_file), ''))
        for [cmd, cnt] in items(l:cmds)
          let l:all_commands[cmd] = get(l:all_commands, cmd, 0) + cnt
        endfor
      catch
      endtry
    endif

    " Load mappings
    let l:map_file = l:data_dir . '/mappings-' . l:date . '.json'
    if filereadable(l:map_file)
      try
        let l:maps = json_decode(join(readfile(l:map_file), ''))
        for [mapping, data] in items(l:maps)
          if has_key(l:all_mappings, mapping)
            let l:all_mappings[mapping].count += data.count
          else
            let l:all_mappings[mapping] = data
          endif
        endfor
      catch
      endtry
    endif
  endfor

  " Load session data
  let l:session_file = l:data_dir . '/sessions.jsonl'
  if filereadable(l:session_file)
    for line in readfile(l:session_file)
      try
        let l:session = json_decode(line)
        if l:session.event == 'end'
          let l:total_sessions += 1
          let l:total_duration += get(l:session, 'duration', 0)
        endif
      catch
      endtry
    endfor
  endif

  " Display in a new buffer
  call s:OpenStatsBuffer('VimStats')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '                    VIM USAGE STATISTICS')
  call append('$', '                    Last ' . l:days . ' days')
  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '')

  " Session summary
  call append('$', '── SESSION SUMMARY ─────────────────────────────────────────────')
  call append('$', printf('  Total sessions: %d', l:total_sessions))
  call append('$', printf('  Total time: %s', s:FormatDuration(l:total_duration)))
  if l:total_sessions > 0
    call append('$', printf('  Avg session: %s', s:FormatDuration(l:total_duration / l:total_sessions)))
  endif
  call append('$', '')

  " Top commands
  call append('$', '── TOP 20 COMMANDS ─────────────────────────────────────────────')
  let l:sorted_cmds = s:SortByCount(l:all_commands)
  let l:count = 0
  for [cmd, cnt] in l:sorted_cmds
    if l:count >= 20
      break
    endif
    call append('$', printf('  %5d  %s', cnt, cmd))
    let l:count += 1
  endfor
  if empty(l:sorted_cmds)
    call append('$', '  (no command data yet)')
  endif
  call append('$', '')

  " Top mappings
  call append('$', '── TOP 20 MAPPINGS ─────────────────────────────────────────────')
  let l:sorted_maps = []
  for [mapping, data] in items(l:all_mappings)
    call add(l:sorted_maps, [mapping, data.count, get(data, 'desc', '')])
  endfor
  call sort(l:sorted_maps, {a, b -> b[1] - a[1]})
  let l:count = 0
  for [mapping, cnt, desc] in l:sorted_maps
    if l:count >= 20
      break
    endif
    let l:display = desc != '' ? mapping . ' (' . desc . ')' : mapping
    call append('$', printf('  %5d  %s', cnt, l:display))
    let l:count += 1
  endfor
  if empty(l:sorted_maps)
    call append('$', '  (no mapping data yet)')
  endif
  call append('$', '')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '  Commands: :VimStatsTypos :VimStatsUnused :VimStatsMappings')
  call append('$', '═══════════════════════════════════════════════════════════════')

  " Clean up first empty line and position cursor
  silent! 1delete _
  normal! gg
  setlocal nomodifiable
endfunction

" Show detected typos
function! vim_stats#ShowTypos() abort
  let l:data_dir = g:vim_stats_data_dir
  let l:typos = {}

  " Load typo data from all files
  let l:files = glob(l:data_dir . '/typos-*.jsonl', 0, 1)
  for file in l:files
    for line in readfile(file)
      try
        let l:typo = json_decode(line)
        let l:key = l:typo.failed . ' -> ' . l:typo.succeeded
        let l:typos[l:key] = get(l:typos, l:key, 0) + 1
      catch
      endtry
    endfor
  endfor

  call s:OpenStatsBuffer('VimStatsTypos')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '                    DETECTED TYPOS')
  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '')
  call append('$', '  Sequences that failed then succeeded with minor changes:')
  call append('$', '')

  let l:sorted = s:SortByCount(l:typos)
  if empty(l:sorted)
    call append('$', '  (no typos detected yet)')
  else
    for [typo, cnt] in l:sorted
      call append('$', printf('  %5d  %s', cnt, typo))
    endfor
  endif

  call append('$', '')
  call append('$', '  TIP: Frequent typos might indicate need for remapping')
  call append('$', '═══════════════════════════════════════════════════════════════')

  silent! 1delete _
  normal! gg
  setlocal nomodifiable
endfunction

" Show unused mappings (mappings defined but never/rarely used)
function! vim_stats#ShowUnused() abort
  let l:data_dir = g:vim_stats_data_dir

  " Get all defined mappings
  let l:defined_mappings = s:GetDefinedMappings()

  " Get used mappings from stats
  let l:used_mappings = {}
  let l:files = glob(l:data_dir . '/mappings-*.json', 0, 1)
  for file in l:files
    try
      let l:data = json_decode(join(readfile(file), ''))
      for [mapping, info] in items(l:data)
        let l:used_mappings[mapping] = get(l:used_mappings, mapping, 0) + info.count
      endfor
    catch
    endtry
  endfor

  call s:OpenStatsBuffer('VimStatsUnused')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '                    UNUSED MAPPINGS')
  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '')
  call append('$', '  Mappings defined in your config but rarely/never used:')
  call append('$', '')

  let l:unused = []
  let l:rarely_used = []

  for [mapping, info] in items(l:defined_mappings)
    let l:uses = get(l:used_mappings, mapping, 0)
    if l:uses == 0
      call add(l:unused, [mapping, info.mode, info.rhs])
    elseif l:uses < 5
      call add(l:rarely_used, [mapping, info.mode, info.rhs, l:uses])
    endif
  endfor

  if !empty(l:unused)
    call append('$', '── NEVER USED ──────────────────────────────────────────────────')
    for [mapping, mode, rhs] in l:unused
      call append('$', printf('  [%s] %s -> %s', mode, mapping, rhs[:50]))
    endfor
    call append('$', '')
  endif

  if !empty(l:rarely_used)
    call append('$', '── RARELY USED (<5 times) ──────────────────────────────────────')
    for [mapping, mode, rhs, uses] in l:rarely_used
      call append('$', printf('  [%s] %s -> %s (%d uses)', mode, mapping, rhs[:40], uses))
    endfor
    call append('$', '')
  endif

  if empty(l:unused) && empty(l:rarely_used)
    call append('$', '  All your mappings are being used! Great config.')
  endif

  call append('$', '')
  call append('$', '  TIP: Consider removing unused mappings to simplify your config')
  call append('$', '═══════════════════════════════════════════════════════════════')

  silent! 1delete _
  normal! gg
  setlocal nomodifiable
endfunction

" Show all mappings usage
function! vim_stats#ShowMappings() abort
  let l:data_dir = g:vim_stats_data_dir
  let l:defined = s:GetDefinedMappings()
  let l:used = {}

  let l:files = glob(l:data_dir . '/mappings-*.json', 0, 1)
  for file in l:files
    try
      let l:data = json_decode(join(readfile(file), ''))
      for [mapping, info] in items(l:data)
        let l:used[mapping] = get(l:used, mapping, 0) + info.count
      endfor
    catch
    endtry
  endfor

  call s:OpenStatsBuffer('VimStatsMappings')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '                    MAPPING USAGE')
  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '')

  " Combine defined and used
  let l:all = {}
  for [mapping, info] in items(l:defined)
    let l:all[mapping] = {'mode': info.mode, 'rhs': info.rhs, 'uses': get(l:used, mapping, 0), 'defined': 1}
  endfor
  for [mapping, cnt] in items(l:used)
    if !has_key(l:all, mapping)
      let l:all[mapping] = {'mode': '?', 'rhs': '(unknown)', 'uses': cnt, 'defined': 0}
    endif
  endfor

  " Sort by usage
  let l:sorted = []
  for [mapping, info] in items(l:all)
    call add(l:sorted, [mapping, info])
  endfor
  call sort(l:sorted, {a, b -> b[1].uses - a[1].uses})

  call append('$', printf('  %-6s %-15s %6s  %s', 'Mode', 'Mapping', 'Uses', 'Action'))
  call append('$', '  ' . repeat('-', 60))

  for [mapping, info] in l:sorted
    let l:status = info.defined ? '' : ' *'
    call append('$', printf('  [%s]   %-15s %6d  %s%s', info.mode, mapping, info.uses, info.rhs[:35], l:status))
  endfor

  call append('$', '')
  call append('$', '  * = mapping not found in current config (may be from plugin)')
  call append('$', '═══════════════════════════════════════════════════════════════')

  silent! 1delete _
  normal! gg
  setlocal nomodifiable
endfunction

" Show command usage
function! vim_stats#ShowCommands() abort
  let l:data_dir = g:vim_stats_data_dir
  let l:all_commands = {}

  let l:files = glob(l:data_dir . '/commands-*.json', 0, 1)
  for file in l:files
    try
      let l:data = json_decode(join(readfile(file), ''))
      for [cmd, cnt] in items(l:data)
        let l:all_commands[cmd] = get(l:all_commands, cmd, 0) + cnt
      endfor
    catch
    endtry
  endfor

  call s:OpenStatsBuffer('VimStatsCommands')

  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '                    COMMAND LINE USAGE')
  call append('$', '═══════════════════════════════════════════════════════════════')
  call append('$', '')

  let l:sorted = s:SortByCount(l:all_commands)
  if empty(l:sorted)
    call append('$', '  (no command data yet)')
  else
    " Group by command type
    let l:writes = []
    let l:navigation = []
    let l:search = []
    let l:other = []

    for [cmd, cnt] in l:sorted
      if cmd =~# '^w\|^x\|^q\|^wq\|^update'
        call add(l:writes, [cmd, cnt])
      elseif cmd =~# '^e \|^b\|^tab\|^sp\|^vs'
        call add(l:navigation, [cmd, cnt])
      elseif cmd =~# '^s/\|^%s/\|^g/'
        call add(l:search, [cmd, cnt])
      else
        call add(l:other, [cmd, cnt])
      endif
    endfor

    if !empty(l:writes)
      call append('$', '── FILE OPERATIONS ─────────────────────────────────────────────')
      for [cmd, cnt] in l:writes[:9]
        call append('$', printf('  %5d  %s', cnt, cmd[:60]))
      endfor
      call append('$', '')
    endif

    if !empty(l:search)
      call append('$', '── SEARCH & REPLACE ────────────────────────────────────────────')
      for [cmd, cnt] in l:search[:9]
        call append('$', printf('  %5d  %s', cnt, cmd[:60]))
      endfor
      call append('$', '')
    endif

    if !empty(l:navigation)
      call append('$', '── NAVIGATION ──────────────────────────────────────────────────')
      for [cmd, cnt] in l:navigation[:9]
        call append('$', printf('  %5d  %s', cnt, cmd[:60]))
      endfor
      call append('$', '')
    endif

    if !empty(l:other)
      call append('$', '── OTHER ───────────────────────────────────────────────────────')
      for [cmd, cnt] in l:other[:19]
        call append('$', printf('  %5d  %s', cnt, cmd[:60]))
      endfor
    endif
  endif

  call append('$', '')
  call append('$', '  TIP: Frequent commands might benefit from custom mappings')
  call append('$', '═══════════════════════════════════════════════════════════════')

  silent! 1delete _
  normal! gg
  setlocal nomodifiable
endfunction

" Clear all stats data
function! vim_stats#ClearStats() abort
  let l:choice = confirm('Clear all vim-stats data?', "&Yes\n&No", 2)
  if l:choice == 1
    let l:files = glob(g:vim_stats_data_dir . '/*', 0, 1)
    for file in l:files
      call delete(file)
    endfor
    echo 'Stats cleared.'
  endif
endfunction

" ============================================================================
" Helper functions
" ============================================================================

" Helper: Open a stats buffer
function! s:OpenStatsBuffer(name) abort
  let l:bufname = a:name

  " Check if buffer already exists
  let l:bufnr = bufnr(l:bufname)
  if l:bufnr != -1
    execute 'buffer' l:bufnr
    setlocal modifiable
    silent! %delete _
  else
    execute 'new' l:bufname
  endif

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nowrap
  setlocal nobuflisted
  setlocal filetype=vim-stats

  " Key mappings for the stats buffer
  nnoremap <buffer> q :close<CR>
  nnoremap <buffer> <Esc> :close<CR>
endfunction

" Helper: Sort dictionary by count value
function! s:SortByCount(dict) abort
  let l:list = []
  for [key, cnt] in items(a:dict)
    call add(l:list, [key, cnt])
  endfor
  return sort(l:list, {a, b -> b[1] - a[1]})
endfunction

" Helper: Format duration in human readable format
function! s:FormatDuration(seconds) abort
  let l:hours = a:seconds / 3600
  let l:minutes = (a:seconds % 3600) / 60
  let l:secs = a:seconds % 60

  if l:hours > 0
    return printf('%dh %dm', l:hours, l:minutes)
  elseif l:minutes > 0
    return printf('%dm %ds', l:minutes, l:secs)
  else
    return printf('%ds', l:secs)
  endif
endfunction

" Helper: Get all defined mappings from current vim session
function! s:GetDefinedMappings() abort
  let l:mappings = {}

  " Get mappings for different modes
  for mode in ['n', 'i', 'v', 'x', 'o']
    redir => l:output
    silent execute mode . 'map'
    redir END

    for line in split(l:output, "\n")
      " Parse mapping line: mode lhs rhs
      let l:match = matchlist(line, '^\([nvixo ]\)\s\+\(\S\+\)\s\+\(.*\)$')
      if !empty(l:match)
        let l:lhs = l:match[2]
        let l:rhs = substitute(l:match[3], '^\*\?\s*', '', '')
        " Skip plugin mappings (usually start with <Plug>)
        if l:lhs !~# '<Plug>' && l:lhs !~# '^<SNR>'
          let l:mappings[l:lhs] = {'mode': mode, 'rhs': l:rhs}
        endif
      endif
    endfor
  endfor

  return l:mappings
endfunction
