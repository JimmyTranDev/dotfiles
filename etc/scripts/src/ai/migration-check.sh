#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

detect_migration_tool() {
	local dir="$1"

	if compgen -G "$dir/src/main/resources/db/migration/V*.sql" >/dev/null 2>&1; then
		echo "flyway|$dir/src/main/resources/db/migration"
		return 0
	fi

	local liquibase_dir
	for pattern in "$dir"/**/changelog*.xml "$dir"/**/changelog*.yaml "$dir"/**/changelog*.yml; do
		if compgen -G "$pattern" >/dev/null 2>&1; then
			liquibase_dir=$(dirname "$(compgen -G "$pattern" | head -1)")
			echo "liquibase|$liquibase_dir"
			return 0
		fi
	done

	if [[ -d "$dir/drizzle" ]]; then
		echo "drizzle|$dir/drizzle"
		return 0
	fi

	if [[ -d "$dir/migrations" ]]; then
		echo "generic|$dir/migrations"
		return 0
	fi

	if [[ -d "$dir/prisma/migrations" ]]; then
		echo "prisma|$dir/prisma/migrations"
		return 0
	fi

	echo "unknown|"
	return 1
}

classify_risk() {
	local ops="$1"
	if echo "$ops" | grep -qiE 'DROP TABLE|TRUNCATE'; then
		echo "high"
	elif echo "$ops" | grep -qiE 'DROP COLUMN|RENAME'; then
		echo "medium"
	elif echo "$ops" | grep -qiE 'ALTER'; then
		echo "low"
	else
		echo "none"
	fi
}

scan_migrations() {
	local dir="$1"

	local detection
	detection=$(detect_migration_tool "$dir") || {
		log_error "No migration framework detected in $dir"
		json_output "$(json_obj_raw \
			"migration_tool" "$(json_escape "unknown")" \
			"migration_dir" "$(json_escape "$dir")" \
			"total_files" "0" \
			"files" "[]")"
		return 0
	}

	local tool="${detection%%|*}"
	local migration_dir="${detection##*|}"

	log_info "Detected $tool migrations in $migration_dir" >&2

	local files_arr=()
	local total_files=0

	while IFS= read -r sql_file; do
		[[ -z "$sql_file" ]] && continue
		total_files=$((total_files + 1))

		local destructive_ops=()
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			local upper_line
			upper_line=$(echo "$line" | tr '[:lower:]' '[:upper:]' | sed 's/^[[:space:]]*//')

			if echo "$upper_line" | grep -qE 'DROP[[:space:]]+TABLE'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			elif echo "$upper_line" | grep -qE 'DROP[[:space:]]+COLUMN'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			elif echo "$upper_line" | grep -qE 'ALTER[[:space:]]+TABLE.*DROP'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			elif echo "$upper_line" | grep -qE 'RENAME[[:space:]]+TABLE'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			elif echo "$upper_line" | grep -qE 'RENAME[[:space:]]+COLUMN'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			elif echo "$upper_line" | grep -qE '^TRUNCATE'; then
				destructive_ops+=("$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 200)")
			fi
		done <"$sql_file"

		if [[ ${#destructive_ops[@]} -gt 0 ]]; then
			local ops_json
			ops_json=$(json_arr "${destructive_ops[@]}")

			local ops_concat
			ops_concat=$(printf '%s\n' "${destructive_ops[@]}")
			local risk
			risk=$(classify_risk "$ops_concat")

			local rel_path="${sql_file#$dir/}"
			local obj
			obj=$(json_obj_raw \
				"path" "$(json_escape "$rel_path")" \
				"destructive_ops" "$ops_json" \
				"risk_level" "$(json_escape "$risk")")
			files_arr+=("$obj")
		fi
	done < <(find "$migration_dir" -name "*.sql" -type f 2>/dev/null | sort)

	local files_json
	files_json=$(json_arr_raw "${files_arr[@]}")

	local rel_migration_dir="${migration_dir#$dir/}"
	local result
	result=$(json_obj_raw \
		"migration_tool" "$(json_escape "$tool")" \
		"migration_dir" "$(json_escape "$rel_migration_dir")" \
		"total_files" "$total_files" \
		"files" "$files_json")

	json_output "$result"
}

show_help() {
	echo "Usage: migration-check.sh [directory]"
	echo ""
	echo "Scan migration files for destructive operations as JSON."
	echo ""
	echo "Options:"
	echo "  --help    Show this help message"
}

main() {
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	scan_migrations "$dir"
}

main "$@"
