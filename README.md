# region-highlight.nvim

A Neovim plugin for persistently highlighting code regions with automatic overlap resolution.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vsuhanov/region-highlight.nvim',
  config = function()
    require('region-highlight').setup({
      -- your configuration here
    })
  end
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'vsuhanov/region-highlight.nvim',
  config = function()
    require('region-highlight').setup({
      -- your configuration here
    })
  end
}
```

## Configuration

```lua
require('region-highlight').setup({
  -- Customize colors for dark mode (10 colors)
  colors_dark = {
    '#2d3748',
    '#3c366b',
    '#2c5282',
    '#2c7a7b',
    '#276749',
    '#744210',
    '#742a2a',
    '#5a3e1b',
    '#553c9a',
    '#1e4e5f',
  },
  -- Customize colors for light mode (10 colors)
  colors_light = {
    '#e2e8f0',
    '#e9d8fd',
    '#bee3f8',
    '#b2f5ea',
    '#c6f6d5',
    '#feebc8',
    '#fed7d7',
    '#fefcbf',
    '#ddd6fe',
    '#c4f1f9',
  },
  -- Path to JSON file for storing highlights (default: stdpath('data')/region-highlights.json)
  highlights_file = vim.fn.stdpath('data') .. '/region-highlights.json',
})
```

## Usage

### Commands

#### `:RegionHighlight`

Highlights the selected line range with a background color.

```vim
" Select lines in visual mode (V) then run:
:RegionHighlight

" Or specify a range directly:
:10,20RegionHighlight
```

#### `:RegionHighlightClear`

Clears the entire highlighted region that contains the current line.

```vim
" Move cursor to a highlighted line and run:
:RegionHighlightClear
```

#### `:RegionHighlightClearAll`

Clears all highlighted regions in the current file.

```vim
" Clear all highlights in the current file:
:RegionHighlightClearAll
```

### How it works

1. When you highlight a region, the plugin:
   - Calculates a hash from the filename and line range to pick a consistent color
   - Checks for overlaps with existing highlights and resolves them (splits/trims overlapping regions)
   - Saves the highlight to a JSON file for persistence
   - Applies the highlight to the buffer

2. When you open a file:
   - The plugin automatically loads and applies saved highlights from the JSON file

3. When you clear a highlight at a line:
   - The entire region containing that line is removed
   - The JSON file is updated

### API Functions

```lua
local rh = require('region-highlight')

-- Manually switch to light mode
rh.setLightMode()

-- Manually switch to dark mode
rh.setDarkMode()

-- Programmatically highlight a range
rh.highlight_range(10, 20)

-- Programmatically clear highlight at a line
rh.clear_highlight_at_line(15)

-- Programmatically clear all highlights in current file
rh.clear_all_highlights()
```

### Features

- **Persistent highlights**: Highlights are saved to a JSON file and restored when you open files
- **Deterministic colors**: The same filename + line range always gets the same color
- **Automatic overlap resolution**: New highlights automatically split/trim overlapping regions
- **Dark/Light mode support**: Automatically switches colors based on `background` setting
- **Low priority highlighting**: Won't interfere with syntax highlighting or other highlights
- **Easy clearing**: Place cursor on any line in a highlighted region and clear the entire region

## License

MIT
