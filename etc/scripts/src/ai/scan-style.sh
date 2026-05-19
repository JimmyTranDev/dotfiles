#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

show_help() {
	cat <<'EOF'
Usage: scan-style.sh [options] [directory]

Gather file statistics and code samples from a project for style analysis.

OPTIONS:
  -n, --samples NUM    Number of sample files per type (default: 5)
  -h, --help           Show this help

OUTPUT:
  Minified JSON to stdout with file counts, naming patterns, and code samples.
EOF
}

count_files_by_extension() {
	local dir="$1"
	local -a results=()

	while IFS= read -r line; do
		[[ -n "$line" ]] && results+=("$line")
	done < <(find "$dir" -type f \
		-not -path '*/node_modules/*' \
		-not -path '*/.git/*' \
		-not -path '*/dist/*' \
		-not -path '*/build/*' \
		-not -path '*/.next/*' \
		-not -path '*/coverage/*' \
		-not -path '*/__pycache__/*' \
		-not -path '*/target/*' \
		-not -name '*.lock' \
		-not -name 'package-lock.json' \
		-not -name '*.min.*' \
		2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20)

	local json="{"
	local first=true
	for line in "${results[@]}"; do
		local count ext
		count=$(echo "$line" | awk '{print $1}')
		ext=$(echo "$line" | awk '{print $2}')
		if [[ "$first" == "true" ]]; then
			first=false
		else
			json+=","
		fi
		json+="$(json_escape "$ext"):$count"
	done
	json+="}"
	echo "$json"
}

sample_files() {
	local dir="$1"
	local ext="$2"
	local num="$3"

	find "$dir" -type f -name "*.$ext" \
		-not -path '*/node_modules/*' \
		-not -path '*/.git/*' \
		-not -path '*/dist/*' \
		-not -path '*/build/*' \
		-not -path '*/.next/*' \
		-not -path '*/coverage/*' \
		-not -path '*/__pycache__/*' \
		-not -path '*/target/*' \
		2>/dev/null | shuf | head -n "$num"
}

detect_file_naming() {
	local dir="$1"
	local -a files=()

	while IFS= read -r f; do
		[[ -n "$f" ]] && files+=("$(basename "$f" | sed 's/\.[^.]*$//')")
	done < <(find "$dir" -type f \
		-not -path '*/node_modules/*' \
		-not -path '*/.git/*' \
		-not -path '*/dist/*' \
		-not -path '*/build/*' \
		2>/dev/null | head -100)

	local kebab=0 camel=0 pascal=0 snake=0
	for name in "${files[@]}"; do
		if [[ "$name" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)+$ ]]; then
			((kebab++)) || true
		elif [[ "$name" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
			((pascal++)) || true
		elif [[ "$name" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
			((camel++)) || true
		elif [[ "$name" =~ ^[a-z][a-z0-9]*(_[a-z0-9]+)+$ ]]; then
			((snake++)) || true
		fi
	done

	json_obj_raw \
		"kebab_case" "$kebab" \
		"pascal_case" "$pascal" \
		"camel_case" "$camel" \
		"snake_case" "$snake"
}

gather_config_files() {
	local dir="$1"
	local -a configs=()

	local -a candidates=(
		".eslintrc.js" ".eslintrc.json" ".eslintrc.cjs" "eslint.config.js" "eslint.config.mjs" "eslint.config.ts"
		".prettierrc" ".prettierrc.json" ".prettierrc.js" "prettier.config.js" "prettier.config.mjs"
		"tsconfig.json" "tsconfig.base.json"
		"biome.json" "biome.jsonc"
		".editorconfig"
	)

	for candidate in "${candidates[@]}"; do
		if [[ -f "$dir/$candidate" ]]; then
			configs+=("$candidate")
		fi
	done

	json_arr "${configs[@]}"
}

main() {
	local samples_num=5
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-n | --samples) samples_num="$2"; shift 2 ;;
		-h | --help) show_help; exit 0 ;;
		*) dir="$1"; shift ;;
		esac
	done

	dir="$(cd "$dir" && pwd)"
	local project_name
	project_name="$(basename "$dir")"

	log_info "Scanning $dir..." >&2

	local file_counts
	file_counts=$(count_files_by_extension "$dir")

	local file_naming
	file_naming=$(detect_file_naming "$dir")

	local config_files
	config_files=$(gather_config_files "$dir")

	# Get top 3 extensions for sampling
	local -a top_exts=()
	while IFS= read -r ext; do
		[[ -n "$ext" ]] && top_exts+=("$ext")
	done < <(echo "$file_counts" | tr ',' '\n' | sed 's/[{}"]//g' | sort -t: -k2 -rn | head -5 | cut -d: -f1)

	# Sample files for each top extension
	local samples_json="{"
	local first=true
	for ext in "${top_exts[@]}"; do
		local -a sampled_paths=()
		while IFS= read -r f; do
			[[ -n "$f" ]] && sampled_paths+=("${f#$dir/}")
		done < <(sample_files "$dir" "$ext" "$samples_num")

		if [[ "$first" == "true" ]]; then
			first=false
		else
			samples_json+=","
		fi
		samples_json+="$(json_escape "$ext"):$(json_arr "${sampled_paths[@]}")"
	done
	samples_json+="}"

	json_output "$(json_obj_raw \
		"project_name" "$(json_escape "$project_name")" \
		"directory" "$(json_escape "$dir")" \
		"file_counts" "$file_counts" \
		"file_naming" "$file_naming" \
		"config_files" "$config_files" \
		"sample_paths" "$samples_json")"
}

main "$@"
