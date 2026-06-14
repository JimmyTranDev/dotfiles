#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

ADB_SERIAL=""

adb_cmd() {
	if [[ -n "$ADB_SERIAL" ]]; then
		adb -s "$ADB_SERIAL" "$@"
	else
		adb "$@"
	fi
}

# Pull the database plus its -wal/-shm sidecars into /tmp.
# Tries run-as (debug builds) first, then falls back to adb root (emulator).
# Echoes "<method>|<wal_pulled>|<shm_pulled>" on success.
pull_database() {
	local package="$1"
	local db_name="$2"
	local dest="$3"

	local wal_pulled="false"
	local shm_pulled="false"

	if adb_cmd shell run-as "$package" cat "databases/$db_name" >"$dest" 2>/dev/null && [[ -s "$dest" ]]; then
		if adb_cmd shell run-as "$package" cat "databases/$db_name-wal" >"$dest-wal" 2>/dev/null && [[ -s "$dest-wal" ]]; then
			wal_pulled="true"
		else
			rm -f "$dest-wal"
		fi
		if adb_cmd shell run-as "$package" cat "databases/$db_name-shm" >"$dest-shm" 2>/dev/null && [[ -s "$dest-shm" ]]; then
			shm_pulled="true"
		else
			rm -f "$dest-shm"
		fi
		echo "run-as|$wal_pulled|$shm_pulled"
		return 0
	fi

	log_warning "run-as pull failed, trying adb root" >&2
	rm -f "$dest"
	adb_cmd root >/dev/null 2>&1 || true
	local remote="/data/data/$package/databases/$db_name"
	if adb_cmd pull "$remote" "$dest" >/dev/null 2>&1 && [[ -s "$dest" ]]; then
		if adb_cmd pull "$remote-wal" "$dest-wal" >/dev/null 2>&1 && [[ -s "$dest-wal" ]]; then
			wal_pulled="true"
		fi
		if adb_cmd pull "$remote-shm" "$dest-shm" >/dev/null 2>&1 && [[ -s "$dest-shm" ]]; then
			shm_pulled="true"
		fi
		echo "adb-root|$wal_pulled|$shm_pulled"
		return 0
	fi

	return 1
}

# Run a single sqlite3 query, trimming whitespace.
sqlite_query() {
	local db="$1"
	local query="$2"
	sqlite3 "$db" "$query" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

inspect_database() {
	local package="$1"
	local db_name="$2"
	local dest="/tmp/$db_name"

	if ! command -v adb &>/dev/null; then
		log_error "adb not found (install Android SDK platform-tools)"
		exit 1
	fi
	if ! command -v sqlite3 &>/dev/null; then
		log_error "sqlite3 not found (brew install sqlite)"
		exit 1
	fi

	log_info "Pulling $db_name from $package" >&2
	local pull_result
	if ! pull_result=$(pull_database "$package" "$db_name" "$dest"); then
		log_error "Failed to pull $db_name for $package (check package name and that the app is debuggable)"
		exit 1
	fi

	local method="${pull_result%%|*}"
	local rest="${pull_result#*|}"
	local wal_pulled="${rest%%|*}"
	local shm_pulled="${rest##*|}"

	local size_bytes
	size_bytes=$(wc -c <"$dest" | tr -d '[:space:]')

	local journal_mode integrity user_version fk_check
	journal_mode=$(sqlite_query "$dest" "PRAGMA journal_mode;")
	integrity=$(sqlite_query "$dest" "PRAGMA integrity_check;")
	user_version=$(sqlite_query "$dest" "PRAGMA user_version;")
	fk_check=$(sqlite_query "$dest" "PRAGMA foreign_key_check;")
	[[ -z "$fk_check" ]] && fk_check="ok"
	[[ -z "$user_version" ]] && user_version="0"

	local tables_arr=()
	local table
	while IFS= read -r table; do
		[[ -z "$table" ]] && continue
		local count
		count=$(sqlite_query "$dest" "SELECT COUNT(*) FROM \"$table\";")
		[[ -z "$count" ]] && count="0"
		tables_arr+=("$(json_obj_raw \
			"name" "$(json_escape "$table")" \
			"row_count" "$count")")
	done < <(sqlite3 "$dest" ".tables" 2>/dev/null | tr -s '[:space:]' '\n' | sort)

	local tables_json
	tables_json=$(json_arr_raw "${tables_arr[@]}")

	local result
	result=$(json_obj_raw \
		"package" "$(json_escape "$package")" \
		"database" "$(json_escape "$db_name")" \
		"serial" "$(json_escape "$ADB_SERIAL")" \
		"pull_method" "$(json_escape "$method")" \
		"db_path" "$(json_escape "$dest")" \
		"size_bytes" "$size_bytes" \
		"wal_pulled" "$wal_pulled" \
		"shm_pulled" "$shm_pulled" \
		"journal_mode" "$(json_escape "$journal_mode")" \
		"integrity_check" "$(json_escape "$integrity")" \
		"foreign_key_check" "$(json_escape "$fk_check")" \
		"user_version" "$user_version" \
		"tables" "$tables_json")

	log_success "Inspected $db_name (${#tables_arr[@]} tables, integrity: $integrity)" >&2
	json_output "$result"
}

show_help() {
	cat <<'EOF'
Usage: android-db-inspect.sh <package> <db-name> [--serial <serial>]

Pull a SQLite database (plus -wal/-shm sidecars) from an Android emulator and
emit a verification report as minified JSON: pull method, file size, journal
mode, integrity check, foreign key check, user_version, and per-table row counts.

Arguments:
  <package>    Android application package name (e.g., com.example.app)
  <db-name>    Database file name (e.g., app.db)

Options:
  --serial <serial>  Target a specific device when multiple emulators run
  --help             Show this help message
EOF
}

main() {
	local package="" db_name=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--serial)
			ADB_SERIAL="$2"
			shift 2
			;;
		*)
			if [[ -z "$package" ]]; then
				package="$1"
			elif [[ -z "$db_name" ]]; then
				db_name="$1"
			else
				log_error "Unexpected argument: $1"
				show_help
				exit 1
			fi
			shift
			;;
		esac
	done

	if [[ -z "$package" || -z "$db_name" ]]; then
		log_error "Both <package> and <db-name> are required"
		show_help
		exit 1
	fi

	inspect_database "$package" "$db_name"
}

main "$@"
