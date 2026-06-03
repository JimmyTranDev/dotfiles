#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

WORKSPACE_PACKAGE_PATHS=(
	"apps/app/package.json"
	"apps/cli/package.json"
	"apps/desktop/package.json"
	"apps/server/package.json"
	"packages/core/package.json"
	"packages/shared/package.json"
)

APP_JSON_PATH="apps/app/app.json"

bump_semver() {
	local version="$1"
	local bump_type="$2"

	local major minor patch
	major=$(echo "$version" | cut -d. -f1)
	minor=$(echo "$version" | cut -d. -f2)
	patch=$(echo "$version" | cut -d. -f3)

	case "$bump_type" in
	minor)
		echo "$major.$((minor + 1)).0"
		;;
	major)
		echo "$((major + 1)).0.0"
		;;
	*)
		log_error "Unsupported bump type: $bump_type. Use 'minor' or 'major'."
		exit 1
		;;
	esac
}

read_json_field() {
	local file="$1"
	local field="$2"
	node -e "const j=require('$file'); process.stdout.write(String(j.$field ?? ''));"
}

update_package_json_version() {
	local file="$1"
	local new_version="$2"
	node -e "
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('$file', 'utf8'));
if (!('version' in j)) { process.exit(0); }
j.version = '$new_version';
fs.writeFileSync('$file', JSON.stringify(j, null, 2) + '\n');
"
}

has_version_field() {
	local file="$1"
	node -e "
const j = require('$file');
process.exit('version' in j ? 0 : 1);
" 2>/dev/null
}

update_app_json() {
	local file="$1"
	local new_version="$2"
	local new_build_number="$3"
	local new_version_code="$4"
	node -e "
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('$file', 'utf8'));
j.expo.version = '$new_version';
j.expo.ios.buildNumber = '$new_build_number';
j.expo.android.versionCode = $new_version_code;
fs.writeFileSync('$file', JSON.stringify(j, null, 2) + '\n');
"
}

prompt_bump_type() {
	local bump_type
	echo "Select bump type:" >&2
	select bump_type in minor major; do
		if [[ -n "$bump_type" ]]; then
			echo "$bump_type"
			return 0
		fi
	done
}

show_help() {
	echo "Usage: version-bump.sh [minor|major] [--dry-run] [--dir <monorepo-root>]" >&2
	echo "" >&2
	echo "Bump minor or major version across all monorepo workspaces + app.json." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --dry-run   Preview changes without writing any files" >&2
	echo "  --dir       Path to monorepo root (default: current directory)" >&2
	echo "  --help      Show this help message" >&2
}

main() {
	local bump_type=""
	local dry_run=false
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--dry-run)
			dry_run=true
			shift
			;;
		--dir)
			dir="$2"
			shift 2
			;;
		minor | major)
			bump_type="$1"
			shift
			;;
		*)
			log_error "Unknown argument: $1"
			show_help
			exit 1
			;;
		esac
	done

	dir="$(cd "$dir" && pwd)"

	if [[ ! -f "$dir/pnpm-workspace.yaml" ]]; then
		log_error "Not a pnpm monorepo root (pnpm-workspace.yaml not found): $dir"
		exit 1
	fi

	if [[ -z "$bump_type" ]]; then
		bump_type=$(prompt_bump_type)
	fi

	if [[ "$bump_type" != "minor" && "$bump_type" != "major" ]]; then
		log_error "Unsupported bump type: $bump_type. Use 'minor' or 'major'."
		exit 1
	fi

	local app_pkg="$dir/apps/app/package.json"
	local current_version
	current_version=$(read_json_field "$app_pkg" "version")

	if [[ -z "$current_version" ]]; then
		log_error "Could not read version from $app_pkg"
		exit 1
	fi

	local new_version
	new_version=$(bump_semver "$current_version" "$bump_type")

	local app_json="$dir/$APP_JSON_PATH"
	local current_build_number current_version_code
	current_build_number=$(read_json_field "$app_json" "expo.ios.buildNumber")
	current_version_code=$(read_json_field "$app_json" "expo.android.versionCode")

	if ! [[ "$current_build_number" =~ ^[0-9]+$ ]]; then
		log_error "buildNumber is not a valid integer: $current_build_number"
		exit 1
	fi

	if ! [[ "$current_version_code" =~ ^[0-9]+$ ]]; then
		log_error "versionCode is not a valid integer: $current_version_code"
		exit 1
	fi

	local new_build_number=$(( current_build_number + 1 ))
	local new_version_code=$(( current_version_code + 1 ))

	local files_updated=()

	log_info "Bump type: $bump_type"
	log_info "Version: $current_version → $new_version"
	log_info "buildNumber: $current_build_number → $new_build_number"
	log_info "versionCode: $current_version_code → $new_version_code"

	for rel_path in "${WORKSPACE_PACKAGE_PATHS[@]}"; do
		local abs_path="$dir/$rel_path"
		if [[ ! -f "$abs_path" ]]; then
			log_warning "Workspace file not found, skipping: $rel_path"
			continue
		fi
		if has_version_field "$abs_path"; then
			log_info "Updating $rel_path"
			if [[ "$dry_run" == "false" ]]; then
				update_package_json_version "$abs_path" "$new_version"
			fi
			files_updated+=("$rel_path")
		else
			log_info "Skipping $rel_path (no version field)"
		fi
	done

	log_info "Updating $APP_JSON_PATH"
	if [[ "$dry_run" == "false" ]]; then
		update_app_json "$app_json" "$new_version" "$new_build_number" "$new_version_code"
	fi
	files_updated+=("$APP_JSON_PATH")

	local files_json
	files_json=$(printf '%s\n' "${files_updated[@]}" | jq -R . | jq -sc .)

	local dry_run_json
	if [[ "$dry_run" == "true" ]]; then
		dry_run_json="true"
		log_warning "Dry run — no files written"
	else
		dry_run_json="false"
		log_success "Version bump complete: $current_version → $new_version"
	fi

	json_output "$(json_obj_raw \
		"from" "$(json_escape "$current_version")" \
		"to" "$(json_escape "$new_version")" \
		"type" "$(json_escape "$bump_type")" \
		"buildNumber" "$(json_obj_raw "from" "$current_build_number" "to" "$new_build_number")" \
		"versionCode" "$(json_obj_raw "from" "$current_version_code" "to" "$new_version_code")" \
		"filesUpdated" "$files_json" \
		"dryRun" "$dry_run_json")"
}

main "$@"
