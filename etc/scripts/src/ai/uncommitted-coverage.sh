#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

# Empty tree object SHA, used when the repo has no commits yet (unborn HEAD).
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

extract_changed_lines() {
	local dir="$1" ref="$2"

	git -C "$dir" diff "$ref" --unified=0 2>/dev/null | awk '
	/^\+\+\+ / {
		path = $2
		sub(/^b\//, "", path)
		next
	}
	/^@@ / {
		plus = $3
		sub(/^\+/, "", plus)
		n = split(plus, a, ",")
		start = a[1] + 0
		count = (n > 1 ? a[2] + 0 : 1)
		if (path != "" && path != "/dev/null") {
			for (l = 0; l < count; l++) {
				print path "\t" (start + l)
			}
		}
		next
	}
	'
}

sniff_format() {
	local f="$1"

	if grep -q '^SF:' "$f" 2>/dev/null; then
		echo "lcov"
		return
	fi
	if head -1 "$f" 2>/dev/null | grep -q '^mode: '; then
		echo "go"
		return
	fi
	if grep -q '<sourcefile' "$f" 2>/dev/null; then
		echo "jacoco"
		return
	fi
	if grep -q 'clover=' "$f" 2>/dev/null; then
		echo "clover"
		return
	fi
	if grep -q '<line[^>]*num=' "$f" 2>/dev/null; then
		echo "clover"
		return
	fi
	if grep -q 'filename=' "$f" 2>/dev/null && grep -q '<class' "$f" 2>/dev/null; then
		echo "cobertura"
		return
	fi
	if grep -q '<line[^>]*number=' "$f" 2>/dev/null; then
		echo "cobertura"
		return
	fi
	echo "unknown"
}

find_report() {
	local dir="$1"
	local candidates=(
		"coverage/lcov.info"
		"lcov.info"
		"coverage/clover.xml"
		"clover.xml"
		"coverage.xml"
		"coverage/cobertura-coverage.xml"
		"cobertura.xml"
		"target/site/jacoco/jacoco.xml"
		"build/reports/jacoco/test/jacocoTestReport.xml"
		"jacoco.xml"
		"coverage.out"
		"cover.out"
		"coverage.txt"
	)

	local c path fmt
	for c in "${candidates[@]}"; do
		path="$dir/$c"
		if [[ -f "$path" ]]; then
			fmt=$(sniff_format "$path")
			if [[ "$fmt" != "unknown" ]]; then
				printf '%s:%s' "$fmt" "$path"
				return 0
			fi
		fi
	done
	return 1
}

parse_report() {
	local fmt="$1" file="$2" root="$3" gomod="$4"

	case "$fmt" in
	lcov | go)
		awk -v fmt="$fmt" -v root="$root" -v module="$gomod" '
		function striproot(f) {
			sub(/^\.\//, "", f)
			if (root != "" && index(f, root "/") == 1) {
				f = substr(f, length(root) + 2)
			}
			return f
		}
		fmt == "lcov" && /^SF:/ {
			f = striproot(substr($0, 4))
			next
		}
		fmt == "lcov" && /^DA:/ {
			rest = substr($0, 4)
			n = split(rest, a, ",")
			if (n >= 2 && f != "") {
				print f "\t" a[1] + 0 "\t" a[2] + 0
			}
			next
		}
		fmt == "go" && /^mode:/ {
			next
		}
		fmt == "go" && NF >= 3 {
			spec = $1
			cnt = $NF + 0
			pos = 0
			for (i = length(spec); i >= 1; i--) {
				if (substr(spec, i, 1) == ":") {
					pos = i
					break
				}
			}
			if (pos == 0) {
				next
			}
			path = substr(spec, 1, pos - 1)
			rng = substr(spec, pos + 1)
			ci = index(rng, ",")
			if (ci == 0) {
				next
			}
			left = substr(rng, 1, ci - 1)
			right = substr(rng, ci + 1)
			dl = index(left, ".")
			dr = index(right, ".")
			sL = (dl > 0 ? substr(left, 1, dl - 1) : left) + 0
			eL = (dr > 0 ? substr(right, 1, dr - 1) : right) + 0
			if (module != "") {
				sub(module "/", "", path)
			}
			path = striproot(path)
			for (l = sL; l <= eL; l++) {
				print path "\t" l "\t" (cnt > 0 ? 1 : 0)
			}
			next
		}
		' "$file"
		;;
	clover | cobertura | jacoco)
		awk -v RS='<' -v fmt="$fmt" -v root="$root" '
		function attr(s, name,   re, p, rest, q) {
			re = name "=\""
			p = index(s, re)
			if (p == 0) {
				return ""
			}
			rest = substr(s, p + length(re))
			q = index(rest, "\"")
			if (q == 0) {
				return ""
			}
			return substr(rest, 1, q - 1)
		}
		function striproot(f) {
			sub(/^\.\//, "", f)
			if (root != "" && index(f, root "/") == 1) {
				f = substr(f, length(root) + 2)
			}
			return f
		}
		fmt == "clover" && /^file / {
			p = attr($0, "path")
			if (p == "") {
				p = attr($0, "name")
			}
			f = striproot(p)
			next
		}
		fmt == "clover" && /^line / {
			ln = attr($0, "num")
			if (ln != "" && f != "") {
				ct = attr($0, "count")
				print f "\t" ln + 0 "\t" (ct == "" ? 0 : ct + 0)
			}
			next
		}
		fmt == "cobertura" && /^class / {
			nf = attr($0, "filename")
			if (nf != "") {
				f = striproot(nf)
			}
			next
		}
		fmt == "cobertura" && /^line / {
			ln = attr($0, "number")
			if (ln != "" && f != "") {
				ht = attr($0, "hits")
				print f "\t" ln + 0 "\t" (ht == "" ? 0 : ht + 0)
			}
			next
		}
		fmt == "jacoco" && /^package / {
			pkg = attr($0, "name")
			next
		}
		fmt == "jacoco" && /^sourcefile / {
			sf = attr($0, "name")
			f = striproot((pkg == "" ? sf : pkg "/" sf))
			next
		}
		fmt == "jacoco" && /^line / {
			nr = attr($0, "nr")
			if (nr != "" && f != "") {
				ci = attr($0, "ci")
				print f "\t" nr + 0 "\t" ((ci + 0) > 0 ? 1 : 0)
			}
			next
		}
		' "$file"
		;;
	esac
}

intersect() {
	local cov="$1" changed="$2"

	awk -F'\t' '
	function endswith(s, suf) {
		if (length(suf) > length(s)) {
			return 0
		}
		return substr(s, length(s) - length(suf) + 1) == suf
	}
	function smatch(a, b) {
		if (a == b) {
			return 1
		}
		if (endswith(a, "/" b)) {
			return 1
		}
		if (endswith(b, "/" a)) {
			return 1
		}
		return 0
	}
	FNR == NR {
		key = $1 SUBSEP ($2 + 0)
		h = $3 + 0
		if (!(key in cov) || h > cov[key]) {
			cov[key] = h
		}
		if (!($1 in haspath)) {
			haspath[$1] = 1
			cpaths[++ncp] = $1
		}
		next
	}
	{
		P = $1
		L = $2 + 0
		if (!(P in seen)) {
			seen[P] = 1
			plist[++np] = P
		}
		chp[++nc] = P
		chl[nc] = L
	}
	END {
		for (i = 1; i <= np; i++) {
			P = plist[i]
			if (P in haspath) {
				resolve[P] = P
				continue
			}
			resolve[P] = ""
			for (j = 1; j <= ncp; j++) {
				if (smatch(P, cpaths[j])) {
					resolve[P] = cpaths[j]
					break
				}
			}
		}
		tcov = 0
		ttot = 0
		for (k = 1; k <= nc; k++) {
			P = chp[k]
			L = chl[k]
			rp = resolve[P]
			if (rp == "") {
				continue
			}
			key = rp SUBSEP L
			if (key in cov) {
				ttot++
				fTot[P]++
				if (cov[key] > 0) {
					tcov++
					fCov[P]++
				}
			}
		}
		print "TOTAL\t" tcov "\t" ttot
		for (i = 1; i <= np; i++) {
			P = plist[i]
			if (fTot[P] > 0) {
				print "FILE\t" P "\t" (fCov[P] + 0) "\t" fTot[P]
			}
		}
	}
	' "$cov" "$changed"
}

emit_empty() {
	json_output "$(json_obj_raw \
		"changed_lines" "0" \
		"covered" "0" \
		"coverage_pct" "null" \
		"files" "[]")"
}

emit_json() {
	local summary="$1"

	local covered coverable
	covered=$(printf '%s\n' "$summary" | awk -F'\t' '$1 == "TOTAL" { print $2; exit }')
	coverable=$(printf '%s\n' "$summary" | awk -F'\t' '$1 == "TOTAL" { print $3; exit }')
	covered=${covered:-0}
	coverable=${coverable:-0}

	local pct
	if [[ "$coverable" -gt 0 ]]; then
		pct=$(LC_ALL=C awk -v c="$covered" -v t="$coverable" 'BEGIN { printf "%.2f", c / t * 100 }')
	else
		pct="null"
	fi

	local files_arr=()
	local tag fpath fcov ftot fpct
	while IFS=$'\t' read -r tag fpath fcov ftot; do
		if [[ "$tag" != "FILE" ]]; then
			continue
		fi
		if [[ "${ftot:-0}" -gt 0 ]]; then
			fpct=$(LC_ALL=C awk -v c="$fcov" -v t="$ftot" 'BEGIN { printf "%.2f", c / t * 100 }')
		else
			fpct="null"
		fi
		files_arr+=("$(json_obj_raw "path" "$(json_escape "$fpath")" "pct" "$fpct")")
	done < <(printf '%s\n' "$summary" | sort)

	local files_json
	files_json=$(json_arr_raw "${files_arr[@]}")

	json_output "$(json_obj_raw \
		"changed_lines" "$coverable" \
		"covered" "$covered" \
		"coverage_pct" "$pct" \
		"files" "$files_json")"
}

compute_coverage() {
	local dir="$1" no_run="$2"

	require_git_repo "$dir" || return 1

	local root gomod ref
	root="$(cd "$dir" && pwd)"
	gomod=""
	if [[ -f "$dir/go.mod" ]]; then
		gomod=$(awk 'NR == 1 && $1 == "module" { print $2; exit }' "$dir/go.mod" 2>/dev/null || true)
	fi
	if git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
		ref="HEAD"
	else
		ref="$EMPTY_TREE"
	fi

	local tmp
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' RETURN

	extract_changed_lines "$dir" "$ref" >"$tmp/changed.tsv" || true

	local changed_count
	changed_count=$(wc -l <"$tmp/changed.tsv" | tr -d ' ')
	if [[ "${changed_count:-0}" -eq 0 ]]; then
		log_info "No uncommitted changes detected"
		emit_empty
		return 0
	fi
	log_info "Found $changed_count changed line(s) in uncommitted diff"

	local runner
	runner=$(detect_test_runner "$dir")
	if [[ "$no_run" != "true" ]]; then
		if [[ "$runner" == "unknown" ]]; then
			log_warning "No test runner detected; looking for an existing coverage report"
		else
			log_info "Running tests to generate coverage ($runner)"
			"$SCRIPT_DIR/run-tests.sh" "$dir" >&2 || true
		fi
	fi

	local report fmt file
	report=$(find_report "$dir") || true
	if [[ -z "$report" ]]; then
		if [[ "$runner" == "unknown" ]]; then
			log_warning "No coverage tooling and no coverage report found; coverage unknown"
			emit_empty
			return 2
		fi
		log_warning "No parseable coverage report found; coverage unknown"
		emit_empty
		return 3
	fi
	fmt="${report%%:*}"
	file="${report#*:}"
	log_info "Using $fmt coverage report: $file"

	parse_report "$fmt" "$file" "$root" "$gomod" >"$tmp/cov.tsv" || true

	local summary
	summary=$(intersect "$tmp/cov.tsv" "$tmp/changed.tsv")
	emit_json "$summary"
}

show_help() {
	echo "Usage: uncommitted-coverage.sh [--no-run] [directory]" >&2
	echo "" >&2
	echo "Report test coverage of currently-uncommitted (changed) lines." >&2
	echo "Compares 'git diff HEAD' changed lines against the project's coverage report." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --no-run   Skip running the test suite; only parse an existing coverage report" >&2
	echo "  --help     Show this help message" >&2
	echo "" >&2
	echo "Supported reports: lcov, clover, cobertura, jacoco, go cover profile." >&2
	echo "Untracked files are not included (only tracked changes vs HEAD)." >&2
	echo "Exit codes: 0 ok/no-changes, 1 not a git repo, 2 no coverage tooling, 3 no report." >&2
}

main() {
	local dir="." no_run="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--no-run)
			no_run="true"
			shift
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	local rc=0
	compute_coverage "$dir" "$no_run" || rc=$?
	exit "$rc"
}

main "$@"
