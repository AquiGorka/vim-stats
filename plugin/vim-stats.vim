" vim-stats.vim - Unobtrusive usage tracking for Vim
" Tracks commands, mappings, and potential typos without affecting performance
" Author: Generated for AquiGorka
" Version: 1.0

if exists('g:loaded_vim_stats') || &compatible
  finish
endif
let g:loaded_vim_stats = 1

" Configuration with sensible defaults
let g:vim_stats_data_dir = get(g:, 'vim_stats_data_dir', expand('~/.vim/stats'))
let g:vim_stats_enabled = get(g:, 'vim_stats_enabled', 1)
let g:vim_stats_flush_interval = get(g:, 'vim_stats_flush_interval', 30000) " 30 seconds
let g:vim_stats_max_buffer_size = get(g:, 'vim_stats_max_buffer_size', 100)

" User commands
command! VimStatsEnable let g:vim_stats_enabled = 1 | call vim_stats#Init()
command! VimStatsDisable let g:vim_stats_enabled = 0 | call vim_stats#StopTimer()
command! VimStatsFlush call vim_stats#FlushBuffer()
command! -nargs=? VimStats call vim_stats#ShowStats(<q-args>)
command! VimStatsTypos call vim_stats#ShowTypos()
command! VimStatsUnused call vim_stats#ShowUnused()
command! VimStatsMappings call vim_stats#ShowMappings()
command! VimStatsCommands call vim_stats#ShowCommands()
command! VimStatsClear call vim_stats#ClearStats()

" Autocommands for tracking
augroup vim_stats
  autocmd!
  autocmd VimEnter * call vim_stats#Init()
  autocmd VimLeavePre * call vim_stats#Cleanup()
  autocmd CmdlineLeave : call vim_stats#RecordCommand(getcmdline())
augroup END
