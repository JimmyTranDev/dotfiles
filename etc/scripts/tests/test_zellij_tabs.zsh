#!/usr/bin/env zsh
# Tests for the zellij tab-naming helpers in utils/zellij_tabs.sh.
#
# Run: zsh etc/scripts/tests/test_zellij_tabs.zsh
#
# These pin the pure, deterministic core that update_tab_indexes.sh relies on:
#   - resolve_tab_base_name: turns an "nvim"-only tab base name into the focused
#     pane's folder name (and leaves every other name untouched).
#   - parse_focused_tab_folders: reads `zellij action dump-layout` output and
#     prints, per real tab in position order, the focused pane's folder name.
# Neither helper talks to a live zellij session, so they are fully unit-testable.

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/zellij_tabs.sh"

typeset -i PASS=0 FAIL=0

pass() { print -r -- "  ok: $1"; (( PASS++ )); }
fail() {
  print -r -- "FAIL: $1"
  (( FAIL++ ))
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc"
    print -r -- "    expected: [$expected]"
    print -r -- "    actual:   [$actual]"
  fi
}

folders_of() { print -r -- "$1" | parse_focused_tab_folders }

# --- resolve_tab_base_name: only an exact "nvim" base name is overridden -------
assert_eq "nvim base + folder -> folder name" \
  "dotfiles" "$(resolve_tab_base_name "nvim" "dotfiles")"

assert_eq "nvim base + empty folder -> left as nvim" \
  "nvim" "$(resolve_tab_base_name "nvim" "")"

assert_eq "non-nvim base is never overridden" \
  "opencode" "$(resolve_tab_base_name "opencode" "dotfiles")"

assert_eq "already-folder base is left untouched" \
  "massdecide" "$(resolve_tab_base_name "massdecide" "dotfiles")"

assert_eq "match is case-sensitive: Nvim stays Nvim" \
  "Nvim" "$(resolve_tab_base_name "Nvim" "dotfiles")"

assert_eq "substring nvimrc is not treated as nvim" \
  "nvimrc" "$(resolve_tab_base_name "nvimrc" "dotfiles")"

# --- parse_focused_tab_folders: real session layout --------------------------
# Mirrors `zellij action dump-layout` for a single tab whose focused pane is the
# opencode pane (cwd JimmyTranDev/dotfiles). Nested split/stacked container panes
# carry no cwd; the compact-bar plugin pane is ignored; the new_tab_template and
# swap_* template blocks must NOT be counted as real tabs.
real_layout=$(cat <<'KDL'
layout {
    cwd "/Users/jimmy/Programming"
    tab name="1.dotfiles🤖" focus=true hide_floating_panes=true {
        pane split_direction="vertical" {
            pane size="30%" stacked=true {
                pane command="opencode" name="⚙ working · Commit staged…" cwd="JimmyTranDev/dotfiles" {
                    start_suspended true
                }
                pane command="opencode" name="opencode" cwd="JimmyTranDev/dotfiles" focus=true expanded=true {
                    start_suspended true
                }
            }
            pane size="70%" stacked=true {
                pane command="nvim" cwd="JimmyTranDev/dotfiles" expanded=true {
                    start_suspended true
                }
                pane command="nvim" name="nvim" cwd="wcreated/turso-poc-2" {
                    start_suspended true
                }
            }
        }
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
    }
    new_tab_template {
        pane cwd="/Users/jimmy/Programming"
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
    }
    swap_tiled_layout name="vertical" {
        tab max_panes=4 {
            pane cwd="should/not/appear"
        }
    }
}
KDL
)
assert_eq "real layout -> focused pane's folder, templates excluded" \
  "dotfiles" "$(folders_of "$real_layout")"

# --- parse_focused_tab_folders: ordering, focus precedence, fallback ----------
# Tab 1: focused nvim pane -> its folder.
# Tab 2: an earlier opencode pane plus a focused nvim pane -> focus wins.
# Tab 3: no focus marker -> falls back to the first pane that has a cwd.
# Trailing swap layout (with its own inner tab) must be ignored.
multi_layout=$(cat <<'KDL'
layout {
    cwd "/Users/jimmy/Programming"
    tab name="1.nvim" focus=true {
        pane command="nvim" cwd="wcreated/turso-poc-2" focus=true
    }
    tab name="2.proj" {
        pane command="opencode" cwd="JimmyTranDev/massdecide"
        pane command="nvim" cwd="wcreated/other" focus=true
    }
    tab name="3.fallback" {
        pane command="opencode" cwd="JimmyTranDev/dotfiles"
        pane command="nvim" cwd="JimmyTranDev/elsewhere"
    }
    swap_tiled_layout name="vertical" {
        tab max_panes=4 {
            pane cwd="should/not/appear"
        }
    }
}
KDL
)
assert_eq "multi-tab order + focus precedence + first-cwd fallback" \
  $'turso-poc-2\nother\ndotfiles' "$(folders_of "$multi_layout")"

# --- parse_focused_tab_folders: a tab with no cwd yields an empty folder -------
nocwd_layout=$(cat <<'KDL'
layout {
    tab name="1.nvim" focus=true {
        pane command="zsh"
    }
}
KDL
)
assert_eq "tab with no pane cwd -> empty folder line" \
  "" "$(folders_of "$nocwd_layout")"

# --- parse_focused_tab_folders: absolute cwd -> its basename ------------------
abs_layout=$(cat <<'KDL'
layout {
    tab name="1.nvim" focus=true {
        pane command="nvim" cwd="/Users/jimmy/Programming" focus=true
    }
}
KDL
)
assert_eq "absolute cwd -> trailing folder name" \
  "Programming" "$(folders_of "$abs_layout")"

# --- parse_focused_tab_folders: only template blocks -> no output ------------
templates_only=$(cat <<'KDL'
layout {
    cwd "/Users/jimmy/Programming"
    new_tab_template {
        pane cwd="/Users/jimmy/Programming"
    }
    swap_tiled_layout name="vertical" {
        tab max_panes=4 {
            pane
        }
    }
}
KDL
)
assert_eq "no real tabs -> empty output" \
  "" "$(folders_of "$templates_only")"

# --- parse_focused_tab_folders: escaped quotes in a name must not desync braces -
# The tab name carries a lone escaped double quote (odd count). A naive
# quote-toggle flips its in-string parity for the rest of the line and so never
# sees the tab's real opening "{", dropping the whole tab. The escape-aware
# parser still counts that brace and yields the focused pane's "dotfiles".
escaped_layout=$(cat <<'KDL'
layout {
    tab name="weird \" name" focus=true {
        pane command="nvim" cwd="JimmyTranDev/dotfiles" focus=true
    }
}
KDL
)
assert_eq "escaped quotes in tab name do not desync brace counting" \
  "dotfiles" "$(folders_of "$escaped_layout")"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
