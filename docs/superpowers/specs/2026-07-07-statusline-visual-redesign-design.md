# Statusline visual redesign — "grouped two-tone"

**Date:** 2026-07-07
**File touched:** `files/claude/statusline-command.sh` (+ its `files/claude/statusline/test.sh`)
**Type:** presentation-only. No change to which JSON fields are read or to the
token/ctx math (already correct).

## Goal

Turn the flat, space-separated chip line into a scannable, glyph-based line with
logical grouping, a deliberate palette, and a Scripbox-orange accent — without
adding fragility (no powerline background fills, still single non-blocking
render).

Current:
```
🫡 ~/Documents/memory opus-4-8[1m] ctx:8% (fix/ci-chart*↑2) ⟳ 3 learning $13.91 80.8k tokens
```
Target (glyphs shown as names):
```
[folder] ~/…/memory  [chip] opus-4.8 1m │ [gauge] 8% ░░░░░ │ [branch] fix/ci-chart●↑2 │ ⟳ 3  [brush] learning │ [dollar] 13.91  [db] 80.8k
```

## Layout — 5 groups, dim ` │ ` divider, empty groups suppressed

| # | Group | Contents | Glyph (Nerd Font) · colour |
|---|-------|----------|----------------------------|
| 1 | place | cwd, model | folder `U+F07B` grey · path bright-white; chip `U+F2DB` model dim; `[…]` id suffix → dim tag (e.g. `1m`) |
| 2 | ctx   | `NN%` + 5-cell bar | gauge `U+F0E4`; percentage + bar colour-graded green(`<50`)→yellow(`<80`)→red(`≥80`); empty bar cells dim |
| 3 | git   | branch, dirty, ahead | branch `U+E0A0` purple; branch name white; dirty `●`(`U+25CF`) **orange `#E8611A`**; ahead `↑N` blue |
| 4 | meta  | import, style | import `⟳`(`U+27F3`) `N` magenta; style: brush `U+F1FC` + name blue (hidden when `default`) |
| 5 | usage | cost, tokens | dollar `U+F155` + `NN.NN` green; db `U+F1C0` + `NN.Nk`/`NN.NM` blue |

Divider joins only **non-empty** groups, so the no-git / no-meta cases collapse
cleanly (no `│ │`).

## Palette (truecolor, theme-independent — statusline sits on a dark bar)

- accent orange `232,97,26` · bright-white `220,223,228` · glyph-grey `122,128,138`
- divider/empty-bar dim-grey `92,99,112` · branch purple `198,120,221`
- ctx/cost green `152,195,121` · yellow `229,192,123` · red `224,108,117`
- tokens/style/ahead blue `97,175,239`

## Key structural change

Replace the flat `add()` + space-join with **group buffers**: build each of the
5 groups into its own string, `gadd` drops empties, then join non-empty groups
with the dim ` │ ` divider. This is what makes divider suppression correct.

## Correctness fixes rolled in

- **Model `[…]` suffix.** `claude-opus-4-8[1m]` currently renders `opus-4-8[1m]`
  because the `-N-N$` dot-transform can't match with the `[1m]` suffix. Strip a
  trailing `[…]` first, transform `opus-4-8`→`opus-4.8`, re-append the suffix as a
  dim ` 1m` tag.
- **ctx bar fill** = `floor(pct/20)` full cells of 5 (`█`), rest `░`.

## Robustness constraints

- Glyphs emitted as `printf '\xNN\xNN\xNN'` (ASCII source, correct UTF-8 at
  runtime) — never `\uXXXX` literals (mangling hazard) and no bash-4 `\u`
  dependency, so it works on macOS bash 3.2 too.
- Preserve: single `jq` parse, single `git status --porcelain=2 --branch` call,
  import file-as-state refresh, GNU/BSD `stat` fallback, non-blocking render.

## Testing

`test.sh` is rewritten to the new visual contract (the old `ctx:NN%`, `$N.NN`,
`N.Nk tokens` text assertions no longer apply):

- model transform incl. new `[1m]` suffix → `opus-4.8` + `1m` tag
- ctx colour thresholds (truecolor codes) + bar fill (`░░░░░` at 5%, `████░` at 84%)
- tokens `k`/`M`/raw formatting (glyph-prefixed, no "tokens" word)
- cost 2dp (glyph-prefixed, no literal `$`)
- style shown/hidden; import file-as-state
- git branch / dirty `●` / ahead `↑N`
- **grouped join** present; **divider suppression** when no git group
- field order preserved (place→ctx→git→usage)
- adds `SL_OVERRIDE` env so the suite can run against the source pre-`make switch`

Deploy: `cd ~/dotfiles && make switch`; smoke suite (`shelltest`) stays green.
