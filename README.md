# cmp-agents-skills

`nvim-cmp` source for fuzzy-matched agent skill names, powered by [fuzzy.nvim](https://github.com/KoalaVim/fuzzy.nvim).

Scans skill directories (`.claude/skills/`, `.agents/skills/`, etc.) for `SKILL.md` files, extracts names from YAML frontmatter, and provides fuzzy completion with skill descriptions shown in the cmp preview window.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'KoalaVim/cmp-agents-skills',
  dependencies = { 'KoalaVim/fuzzy.nvim' },
  lazy = true,
}
```

## Setup

```lua
require('cmp').setup({
  sources = cmp.config.sources({
    { name = 'agents_skills' },
  }),
})
```

**Note:** the source name is `agents_skills` in cmp's config.

## Configuration

Pass options via `require('cmp_agents_skills').rescan()`:

```lua
require('cmp_agents_skills').rescan({
  dirs = { '.claude/skills', '.agents/skills' },
  roots = nil,           -- nil = auto-detect git root; or list of paths
  fuzzy_backend = 'fzy', -- 'fzf', 'fzy', or 'zf'
  max_items = 15,
})
```

### dirs (type: table of strings)

Relative directory paths under each root to scan for skills. Each directory should contain subdirectories with `SKILL.md` files.

_Default:_ `{ '.claude/skills', '.agents/skills' }`

### roots (type: table of strings | nil)

Root paths to scan. `nil` auto-detects via `git rev-parse --show-toplevel`, falling back to `cwd`.

_Default:_ `nil`

### fuzzy_backend (type: string | nil)

Which fuzzy.nvim backend to use (`'fzf'`, `'fzy'`, `'zf'`). `nil` uses the default.

_Default:_ `nil`

### max_items (type: int)

Maximum number of fuzzy matches to return.

_Default:_ `15`

## Features

- Scans multiple skill directories with configurable roots
- Deduplicates skills by name across directories
- Parses YAML frontmatter for skill name and description
- Shows skill description in cmp's `detail` field
- Shows full skill content (minus frontmatter) in cmp's documentation preview
- Fuzzy matching via fuzzy.nvim with configurable backend

## License

MIT
