#!/bin/bash

# Source-only helpers for naming zellij tabs in update_tab_indexes.sh.
#
# Sourced by both that bash script (macOS bash 3.2) and the zsh test suite, so
# every function here stays portable: scalar arguments in, text on stdout, no
# shell-specific arrays and no top-level side effects.

# resolve_tab_base_name <base_name> <folder>
#
# Decide the base name a tab should carry. A lone nvim pane shows up with the
# base name "nvim"; when that is all the tab is, swap in the focused pane's
# folder name instead so the tab reads like every project tab (e.g. "dotfiles").
# Any other base name — and the empty-folder fallback — is returned unchanged.
# The match is exact and case-sensitive so "nvimrc"/"Nvim" are never touched.
resolve_tab_base_name() {
	local base_name="$1" folder="$2"

	if [[ "$base_name" == "nvim" && -n "$folder" ]]; then
		printf '%s\n' "$folder"
	else
		printf '%s\n' "$base_name"
	fi
}

# parse_focused_tab_folders   (reads `zellij action dump-layout` on stdin)
#
# Print one line per real tab, in position (left-to-right) order: the folder
# name (basename of the cwd) of that tab's focused pane. Tabs with no focused
# pane fall back to the first pane that carries a cwd; tabs with no cwd at all
# print an empty line (so the output stays aligned one-line-per-tab with
# `zellij action list-tabs`). The template blocks zellij appends after the real
# tabs (new_tab_template, swap_tiled_layout, swap_floating_layout) are skipped:
# only `tab` nodes that sit directly inside `layout` (brace depth 1) count.
#
# The parser is a small brace-depth walker rather than a full KDL parser. To
# survive the surrounding `python3 -c "..."` double quotes, the program contains
# no literal double quote, $ or backtick: a double quote is chr(34) and a
# backslash (for unmasking KDL escapes like \") is chr(92).
parse_focused_tab_folders() {
	python3 -c "
import sys, os

Q = chr(34)

def folder_of(cwd):
    if not cwd:
        return ''
    base = os.path.basename(cwd.rstrip('/'))
    if base in ('', '.', '..'):
        return ''
    return base

def get_cwd(line):
    key = 'cwd=' + Q
    i = line.find(key)
    if i < 0:
        return None
    j = i + len(key)
    k = line.find(Q, j)
    if k < 0:
        return None
    return line[j:k]

def mask_strings(line):
    out = []
    inq = False
    esc = False
    BS = chr(92)
    for ch in line:
        if esc:
            esc = False
            continue
        if ch == BS:
            esc = True
            continue
        if ch == Q:
            inq = not inq
        elif not inq:
            out.append(ch)
    return ''.join(out)

depth = 0
in_tab = False
focus_cwd = None
first_cwd = None
results = []

for raw in sys.stdin.read().splitlines():
    s = raw.strip()
    if not s:
        continue
    node_depth = depth
    kw = ''
    for ch in s:
        if ch.isalnum() or ch == '_' or ch == '-':
            kw += ch
        else:
            break
    if kw == 'tab' and node_depth == 1:
        in_tab = True
        focus_cwd = None
        first_cwd = None
    elif in_tab and kw == 'pane':
        cwd = get_cwd(raw)
        if cwd is not None:
            if first_cwd is None:
                first_cwd = cwd
            if focus_cwd is None and 'focus=true' in raw:
                focus_cwd = cwd
    masked = mask_strings(raw)
    depth += masked.count('{') - masked.count('}')
    if in_tab and depth <= 1:
        results.append(folder_of(focus_cwd if focus_cwd else first_cwd))
        in_tab = False
        focus_cwd = None
        first_cwd = None

for r in results:
    print(r)
"
}
