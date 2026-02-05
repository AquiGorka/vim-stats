# vim-stats

> **DISCLAIMER**: This entire plugin was built by an LLM (Claude). I had the idea, wanted to get it out there, and knew this was one of those projects I'd never actually get around to building myself. So I described what I wanted and let the AI write it while I did other things. Use at your own discretion, and feel free to improve upon it.

Unobtrusive usage tracking for Vim. Track your command usage, mapping usage, and detect typos to optimize your configuration.

## Why This Plugin?

I searched for existing solutions and found that **no plugin covers all these features**:

| Plugin | Keystrokes | Commands | Mappings | Unused Detection | Typos | Vim Support |
|--------|:----------:|:--------:|:--------:|:----------------:|:-----:|:-----------:|
| [keystats.nvim](https://github.com/OscarCreator/keystats.nvim) | Yes | No | No | No | No | Neovim only |
| [usage-tracker.nvim](https://github.com/gaborvecsei/usage-tracker.nvim) | Yes | No | No | No | No | Neovim only |
| [tracker.vim](https://github.com/BirdseyeSoftware/tracker.vim) | Yes | No | No | No | No | Requires Python |
| [WakaTime](https://wakatime.com/vim-plugin) | No | No | No | No | No | Yes (cloud-based) |
| [Chronos](https://github.com/hendrikb/chronos) | No | No | No | No | No | GUI Vim only |
| **vim-stats** | Yes | Yes | Yes | Yes | Yes | Yes |

### Gaps in Existing Solutions

- **Unused mapping detection** - No existing plugin analyzes which of your custom mappings you never use
- **Typo detection** - No plugin tracks failed key sequences followed by similar successful ones
- **Ex command tracking** - None track which `:` commands you use most frequently
- **Neovim-only** - The keystroke trackers require Neovim and won't work with standard Vim
- **External dependencies** - WakaTime requires a cloud account; tracker.vim requires Python

## Features

- **Command tracking**: See which Ex commands (`:w`, `:s/...`, etc.) you use most
- **Mapping tracking**: Monitor usage of your custom key mappings
- **Unused mapping detection**: Find mappings you defined but never use
- **Typo detection**: Identify sequences where you fail then succeed with minor changes
- **Session tracking**: Track time spent in Vim sessions

## Performance

This plugin is designed for **zero performance impact**:

- Uses Vim's async job system for file I/O
- Buffers data in memory, flushes every 30 seconds
- No per-keystroke tracking (too expensive)
- Autoload pattern: code loads only when needed
- All heavy operations run in background timers

## Installation

### Using vim-plug

```vim
Plug 'AquiGorka/vim-stats'
```

### Using Vundle

```vim
Plugin 'AquiGorka/vim-stats'
```

### Using pathogen

```bash
cd ~/.vim/bundle
git clone https://github.com/AquiGorka/vim-stats.git
```

### Manual installation

```bash
# Copy to your vim directory
cp -r plugin autoload syntax ftdetect ~/.vim/
```

### Local development (current directory)

Add to your vimrc:

```vim
set runtimepath+=~/Documents/vim-stats
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:VimStats [days]` | Show usage statistics for last N days (default: 7) |
| `:VimStatsTypos` | Show detected typos |
| `:VimStatsUnused` | Show unused/rarely-used mappings |
| `:VimStatsMappings` | Show all mappings with usage counts |
| `:VimStatsCommands` | Show Ex command usage breakdown |
| `:VimStatsEnable` | Enable tracking |
| `:VimStatsDisable` | Disable tracking |
| `:VimStatsFlush` | Manually flush buffered data to disk |
| `:VimStatsClear` | Clear all collected data |

### Example Output

```
═══════════════════════════════════════════════════════════════
                    VIM USAGE STATISTICS
                    Last 7 days
═══════════════════════════════════════════════════════════════

── SESSION SUMMARY ─────────────────────────────────────────────
  Total sessions: 42
  Total time: 18h 34m
  Avg session: 26m 32s

── TOP 20 COMMANDS ─────────────────────────────────────────────
    847  w
    234  e src/
    156  %s/foo/bar/g
    ...

── TOP 20 MAPPINGS ─────────────────────────────────────────────
    523  S (save file)
    412  <space>f (find word under cursor)
    298  Q (quit)
    ...
```

## Configuration

Add to your vimrc:

```vim
" Data storage location (default: ~/.vim/stats)
let g:vim_stats_data_dir = '~/.vim/stats'

" Enable/disable tracking (default: 1)
let g:vim_stats_enabled = 1

" Flush interval in milliseconds (default: 30000 = 30s)
let g:vim_stats_flush_interval = 30000

" Max entries to buffer before flush (default: 100)
let g:vim_stats_max_buffer_size = 100
```

## Tracking Custom Mappings

To track your custom mappings with descriptions, add this after your mapping definitions:

```vim
" Example: Track your custom mapping with a description
nnoremap <silent> <space>f :call vim_stats#RecordMapping('<space>f', 'find word')<CR>*

" Or use the expression mapping approach for zero overhead:
nnoremap <expr> S vim_stats#track#Expr('S', 'save file')
```

For automatic tracking of standard motions (w, b, e, etc.), add to your vimrc:

```vim
" Enable motion tracking (optional, slight overhead)
" call vim_stats#track#SetupMotionTracking()
```

## Data Storage

Data is stored in JSON/JSONL format in `~/.vim/stats/`:

- `commands-YYYY-MM-DD.json` - Ex command counts per day
- `mappings-YYYY-MM-DD.json` - Mapping usage counts per day
- `keys-YYYY-MM-DD.jsonl` - Raw keystroke log (if enabled)
- `typos-YYYY-MM-DD.jsonl` - Detected typo patterns
- `sessions.jsonl` - Session start/end times

## Tips for Config Optimization

1. **Run `:VimStatsUnused` monthly** - Remove mappings you never use
2. **Check `:VimStatsTypos`** - Remap frequent typos to the intended action
3. **Review `:VimStatsCommands`** - Create mappings for frequent commands
4. **Compare mapping usage** - Keep mappings that match your actual workflow

## Analyzing Data

The data files are plain JSON, so you can analyze them with external tools:

```bash
# Top 10 commands this month
cat ~/.vim/stats/commands-*.json | jq -s 'add | to_entries | sort_by(-.value) | .[0:10]'

# Total time in vim
cat ~/.vim/stats/sessions.jsonl | jq -s '[.[] | select(.event=="end") | .duration] | add / 3600'
```

## License

MIT
