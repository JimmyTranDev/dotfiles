#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

SECRETS_DIR="$HOME/Programming/JimmyTranDev/secrets"
BW_ITEM_NAME="dotfiles-secrets"

ensure_bw_unlocked() {
	if ! command -v bw &>/dev/null; then
		log_error "Bitwarden CLI (bw) not found. Install it first."
		exit 1
	fi

	local status
	status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

	if [[ "$status" == "unlocked" ]]; then
		bw sync >/dev/null 2>&1
		log_success "Bitwarden already unlocked and synced"
		return
	fi

	if [[ "$status" == "unauthenticated" ]]; then
		log_info "Logging into Bitwarden..."
		bw login
		status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
	fi

	if [[ "$status" != "unlocked" ]]; then
		if [[ -n "${BW_SESSION:-}" ]]; then
			bw sync >/dev/null 2>&1
			log_success "Bitwarden unlocked via BW_SESSION"
			return
		fi
		log_info "Unlocking Bitwarden vault..."
		BW_SESSION=$(bw unlock --raw)
		export BW_SESSION
	fi

	bw sync >/dev/null 2>&1
	log_success "Bitwarden unlocked and synced"
}

get_item_id() {
	local item_id
	item_id=$(bw get item "$BW_ITEM_NAME" 2>/dev/null | jq -r '.id' 2>/dev/null)
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
	template=$(bw get template item)
	local encoded
	encoded=$(echo "$template" | jq \
		--arg name "$BW_ITEM_NAME" \
		'.name = $name | .type = 2 | .secureNote = {"type": 0} | .notes = ""' | bw encode)
	bw create item "$encoded" >/dev/null
	bw sync >/dev/null 2>&1
	log_success "Created Secure Note '$BW_ITEM_NAME'"
}

remove_existing_attachments() {
	local item_id="$1"
	local attachments
	attachments=$(bw get item "$item_id" 2>/dev/null | jq -r '.attachments[]?.id // empty' 2>/dev/null)

	if [[ -n "$attachments" ]]; then
		while IFS= read -r att_id; do
			[[ -z "$att_id" ]] && continue
			bw delete attachment "$att_id" --itemid "$item_id" >/dev/null 2>&1
		done <<< "$attachments"
	fi
}

upload_secrets() {
	if [[ ! -d "$SECRETS_DIR" ]]; then
		log_error "Secrets directory not found: $SECRETS_DIR"
		exit 1
	fi

	local file_count=0
	while IFS= read -r -d '' _; do
		file_count=$((file_count + 1))
	done < <(find "$SECRETS_DIR" -maxdepth 1 -type f -print0)

	if [[ "$file_count" -eq 0 ]]; then
		log_warning "No files found in $SECRETS_DIR"
		exit 0
	fi

	ensure_bw_unlocked
	create_item_if_missing

	local item_id
	item_id=$(get_item_id)

	log_info "Removing existing attachments..."
	remove_existing_attachments "$item_id"

	local success_count=0
	while IFS= read -r -d '' file; do
		[[ -z "$file" ]] && continue
		local filename
		filename=$(basename "$file")
		log_info "Uploading $filename..."
		bw create attachment --file "$file" --itemid "$item_id" >/dev/null
		success_count=$((success_count + 1))
	done < <(find "$SECRETS_DIR" -maxdepth 1 -type f -print0 | sort -z)

	log_success "Uploaded $success_count files to '$BW_ITEM_NAME'"
}

download_secrets() {
	ensure_bw_unlocked

	local item_id
	item_id=$(get_item_id) || {
		log_error "Bitwarden item '$BW_ITEM_NAME' not found. Run 'upload' first."
		exit 1
	}

	mkdir -p "$SECRETS_DIR"

	local attachments
	attachments=$(bw get item "$item_id" 2>/dev/null | jq -c '.attachments[]?' 2>/dev/null)

	if [[ -z "$attachments" ]]; then
		log_warning "No attachments found on '$BW_ITEM_NAME'"
		exit 0
	fi

	local success_count=0
	while IFS= read -r att; do
		[[ -z "$att" ]] && continue
		local att_id att_name
		att_id=$(echo "$att" | jq -r '.id')
		att_name=$(echo "$att" | jq -r '.fileName')
		log_info "Downloading $att_name..."
		bw get attachment "$att_id" --itemid "$item_id" --output "$SECRETS_DIR/$att_name" >/dev/null
		chmod 600 "$SECRETS_DIR/$att_name"
		success_count=$((success_count + 1))
	done <<< "$attachments"

	log_success "Downloaded $success_count files to $SECRETS_DIR"
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
	upload) upload_secrets ;;
	download) download_secrets ;;
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
