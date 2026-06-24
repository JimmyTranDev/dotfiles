#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

SECRETS_DIR="${SECRETS_DIR:-$HOME/Programming/JimmyTranDev/secrets}"
BW_ITEM_NAME="dotfiles-secrets"
TARBALL_NAME="secrets.tar.gz"

# Cleanup state consumed by the single EXIT/INT/TERM trap below. Functions
# register the scratch dirs they create here instead of installing their own
# traps, so a failure anywhere still removes plaintext on the way out.
_CLEANUP_TMP_DIR=""
_CLEANUP_BACKUP_DIR=""

# Single exit handler: remove any plaintext scratch dirs. Runs on normal exit,
# error exit (set -e), and interrupt. Guards keep each step independent and
# never abort the handler. This script never unlocks the vault itself, so it
# never locks one either — an inherited BW_SESSION is the caller's to manage.
cleanup() {
	if [[ -n "$_CLEANUP_TMP_DIR" ]]; then
		rm -rf "$_CLEANUP_TMP_DIR"
	fi
	if [[ -n "$_CLEANUP_BACKUP_DIR" ]]; then
		rm -rf "$_CLEANUP_BACKUP_DIR"
	fi
}
trap cleanup EXIT INT TERM

ensure_dependencies() {
	local missing=""
	if ! command -v bw >/dev/null 2>&1; then
		missing+="  - bw (install: brew install bitwarden-cli)\n"
	fi
	if ! command -v jq >/dev/null 2>&1; then
		missing+="  - jq (install: brew install jq)\n"
	fi
	if [[ -n "$missing" ]]; then
		log_error "Missing required dependencies:"
		printf "%b" "$missing" >&2
		exit 1
	fi
}

# Require a vault that is already unlocked via an inherited BW_SESSION. This
# script deliberately never logs in or prompts for the master password — the
# caller owns the vault's lifecycle. If the vault is not unlocked we fail fast,
# before any plaintext is written to disk, with instructions to unlock and
# export a session.
ensure_bw_unlocked() {
	local status
	status=$(bw status --nointeraction 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)

	if [[ "$status" != "unlocked" ]]; then
		log_error "Bitwarden vault is not unlocked (status: ${status:-unknown})."
		log_error "Unlock it yourself and export the session, then retry, e.g.:"
		log_error "  export BW_SESSION=\"\$(bw unlock --raw)\""
		exit 1
	fi

	bw sync --nointeraction >/dev/null 2>&1
	log_success "Bitwarden vault synced (using existing BW_SESSION)"
}

get_cached_item() {
	if [[ -z "${_BW_ITEM_CACHE:-}" ]]; then
		local bw_err
		bw_err=$(mktemp)
		_BW_ITEM_CACHE=$(bw get item "$BW_ITEM_NAME" --nointeraction 2>"$bw_err") || true
		if [[ -s "$bw_err" ]]; then
			log_warning "bw get item stderr: $(cat "$bw_err")"
		fi
		rm -f "$bw_err"
	fi
	echo "$_BW_ITEM_CACHE"
}

invalidate_item_cache() {
	_BW_ITEM_CACHE=""
}

get_item_id() {
	local item_json
	item_json=$(get_cached_item)
	if [[ -z "$item_json" ]]; then
		return 1
	fi
	local item_id
	item_id=$(echo "$item_json" | jq -r '.id' 2>/dev/null)
	if [[ -z "$item_id" || "$item_id" == "null" ]]; then
		return 1
	fi
	echo "$item_id"
}

create_item_if_missing() {
	if get_item_id >/dev/null 2>&1; then
		return 0
	fi

	log_info "Creating Bitwarden Secure Note '$BW_ITEM_NAME'..."
	local template
	template=$(bw get template item --nointeraction)
	local encoded
	encoded=$(echo "$template" | jq \
		--arg name "$BW_ITEM_NAME" \
		'.name = $name | .type = 2 | .secureNote = {"type": 0} | .notes = ""' | bw encode)
	bw create item "$encoded" --nointeraction >/dev/null
	bw sync --nointeraction >/dev/null 2>&1
	invalidate_item_cache
	log_success "Created Secure Note '$BW_ITEM_NAME'"
}

upload_secrets() {
	if [[ ! -d "$SECRETS_DIR" ]]; then
		log_error "Secrets directory not found: $SECRETS_DIR"
		exit 1
	fi

	local file_count
	file_count=$(find "$SECRETS_DIR" -type f -not -path '*/.sync_tmp/*' \( -not -path '*/.m2/*' -o -path '*/.m2/settings.xml' \) | wc -l | tr -d ' ')

	if [[ "$file_count" -eq 0 ]]; then
		log_warning "No files found in $SECRETS_DIR"
		exit 0
	fi

	# Authenticate BEFORE writing any plaintext secrets to disk. If unlock
	# fails, no unencrypted tarball is ever created.
	ensure_bw_unlocked
	create_item_if_missing

	local temp_dir="$SECRETS_DIR/.sync_tmp"
	rm -rf "$temp_dir"
	mkdir -p "$temp_dir"
	# Hand the plaintext temp dir to the cleanup trap so it is removed no
	# matter how we leave this function.
	_CLEANUP_TMP_DIR="$temp_dir"

	log_info "Creating tarball of $file_count files..."
	tar czf "$temp_dir/$TARBALL_NAME" -C "$SECRETS_DIR" \
		--exclude='.sync_tmp' \
		--exclude='.sync_backup' \
		--exclude='.m2' \
		--exclude='ssh/agent' \
		.
	if [[ -f "$SECRETS_DIR/.m2/settings.xml" ]]; then
		local uncompressed="$temp_dir/secrets.tar"
		gunzip "$temp_dir/$TARBALL_NAME"
		tar rf "$uncompressed" -C "$SECRETS_DIR" .m2/settings.xml
		gzip "$uncompressed"
		mv "$uncompressed.gz" "$temp_dir/$TARBALL_NAME"
	fi

	local item_json
	item_json=$(get_cached_item)
	local item_id
	item_id=$(echo "$item_json" | jq -r '.id')

	local old_attachment_ids
	old_attachment_ids=$(echo "$item_json" | jq -r '.attachments[]?.id // empty' 2>/dev/null)

	log_info "Uploading tarball..."
	if ! bw create attachment --file "$temp_dir/$TARBALL_NAME" --itemid "$item_id" --nointeraction >/dev/null 2>&1; then
		log_error "Failed to upload tarball"
		exit 1
	fi

	if [[ -n "$old_attachment_ids" ]]; then
		log_info "Removing old attachments..."
		while IFS= read -r att_id; do
			[[ -z "$att_id" ]] && continue
			bw delete attachment "$att_id" --itemid "$item_id" --nointeraction >/dev/null 2>&1 || true
		done <<<"$old_attachment_ids"
	fi

	rm -rf "$temp_dir"
	_CLEANUP_TMP_DIR=""
	log_success "Uploaded $file_count files as tarball to '$BW_ITEM_NAME'"
}

download_secrets() {
	ensure_bw_unlocked

	local item_id
	item_id=$(get_item_id) || {
		log_error "Bitwarden item '$BW_ITEM_NAME' not found. Run 'upload' first."
		exit 1
	}

	local item_json
	item_json=$(get_cached_item)
	local attachments
	attachments=$(echo "$item_json" | jq -c '.attachments[]?' 2>/dev/null)

	if [[ -z "$attachments" ]]; then
		log_warning "No attachments found on '$BW_ITEM_NAME'"
		exit 0
	fi

	local tarball_att_id
	tarball_att_id=$(echo "$item_json" | jq -r '.attachments[] | select(.fileName == "'"$TARBALL_NAME"'") | .id' 2>/dev/null)

	if [[ -z "$tarball_att_id" ]]; then
		log_error "No tarball attachment found. Re-upload secrets with the new format."
		exit 1
	fi

	mkdir -p "$SECRETS_DIR"

	local temp_dir="$SECRETS_DIR/.sync_tmp"
	local backup_dir="$SECRETS_DIR/.sync_backup"
	rm -rf "$temp_dir" "$backup_dir"
	mkdir -p "$temp_dir"

	# Register both scratch dirs with the cleanup trap.
	_CLEANUP_TMP_DIR="$temp_dir"
	_CLEANUP_BACKUP_DIR="$backup_dir"

	log_info "Downloading tarball..."
	if ! bw get attachment "$tarball_att_id" --itemid "$item_id" --output "$temp_dir/$TARBALL_NAME" --nointeraction >/dev/null; then
		log_error "Failed to download tarball"
		exit 1
	fi

	mkdir -p "$backup_dir"
	find "$SECRETS_DIR" -maxdepth 1 -type f -exec cp {} "$backup_dir/" \;

	log_info "Extracting secrets..."
	find "$SECRETS_DIR" -mindepth 1 -not -path "$temp_dir*" -not -path "$backup_dir*" -delete 2>/dev/null || true
	tar xzf "$temp_dir/$TARBALL_NAME" -C "$SECRETS_DIR"

	find "$SECRETS_DIR" -type f -not -path '*/.sync_tmp/*' -not -path '*/.sync_backup/*' -exec chmod 600 {} \;

	local file_count
	file_count=$(find "$SECRETS_DIR" -type f -not -path '*/.sync_tmp/*' -not -path '*/.sync_backup/*' \( -not -path '*/.m2/*' -o -path '*/.m2/settings.xml' \) | wc -l | tr -d ' ')

	rm -rf "$temp_dir" "$backup_dir"
	_CLEANUP_TMP_DIR=""
	_CLEANUP_BACKUP_DIR=""

	log_success "Downloaded $file_count files to $SECRETS_DIR"
}

usage() {
	echo "Usage: $(basename "$0") <upload|download>"
	echo ""
	echo "Commands:"
	echo "  upload     Upload secrets to Bitwarden"
	echo "  download   Download secrets from Bitwarden"
}

main() {
	local command="${1:-}"
	case "$command" in
	upload)
		ensure_dependencies
		upload_secrets
		;;
	download)
		ensure_dependencies
		download_secrets
		;;
	-h | --help | help) usage ;;
	"")
		log_error "No command provided"
		usage
		exit 1
		;;
	*)
		log_error "Unknown command: $command"
		usage
		exit 1
		;;
	esac
}

main "$@"
