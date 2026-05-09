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

upload_secrets() {
	if [[ ! -d "$SECRETS_DIR" ]]; then
		log_error "Secrets directory not found: $SECRETS_DIR"
		exit 1
	fi

	local file_count=0
	while IFS= read -r -d '' _; do
		file_count=$((file_count + 1))
	done < <(find "$SECRETS_DIR" -type f -not -path '*/.sync_tmp/*' -print0)

	if [[ "$file_count" -eq 0 ]]; then
		log_warning "No files found in $SECRETS_DIR"
		exit 0
	fi

	ensure_bw_unlocked
	create_item_if_missing

	local item_id
	item_id=$(get_item_id)

	local old_attachment_ids
	old_attachment_ids=$(bw get item "$item_id" 2>/dev/null | jq -r '.attachments[]?.id // empty' 2>/dev/null)

	local temp_dir="$SECRETS_DIR/.sync_tmp"
	rm -rf "$temp_dir"
	mkdir -p "$temp_dir"

	local success_count=0
	local upload_failed=0
	local new_attachment_ids=""
	local seen_safe_names=""
	while IFS= read -r -d '' file; do
		[[ -z "$file" ]] && continue
		local rel_path
		rel_path="${file#"$SECRETS_DIR"/}"
		local safe_name
		safe_name="${rel_path//\//__SLASH__}"

		if echo "$seen_safe_names" | grep -qxF "$safe_name"; then
			log_error "Name collision detected for '$safe_name' (from '$rel_path') — aborting."
			upload_failed=1
			break
		fi
		seen_safe_names="${seen_safe_names}${safe_name}
"

		cp "$file" "$temp_dir/$safe_name"

		local manifest_line="$safe_name	$rel_path"
		echo "$manifest_line" >> "$temp_dir/.manifest"

		log_info "Uploading $rel_path (as $safe_name)..."
		local upload_output
		if ! upload_output=$(bw create attachment --file "$temp_dir/$safe_name" --itemid "$item_id" 2>&1); then
			log_error "Failed to upload $rel_path — aborting. Old attachments preserved."
			upload_failed=1
			break
		fi
		local new_att_id
		new_att_id=$(echo "$upload_output" | jq -r '.attachments[-1].id // empty' 2>/dev/null)
		if [[ -n "$new_att_id" ]]; then
			new_attachment_ids="${new_attachment_ids}${new_att_id}
"
		fi
		success_count=$((success_count + 1))
	done < <(find "$SECRETS_DIR" -type f -not -path '*/.sync_tmp/*' -print0 | sort -z)

	if [[ "$upload_failed" -eq 0 && -f "$temp_dir/.manifest" ]]; then
		log_info "Uploading manifest..."
		local upload_output
		if ! upload_output=$(bw create attachment --file "$temp_dir/.manifest" --itemid "$item_id" 2>&1); then
			log_error "Failed to upload manifest — aborting. Old attachments preserved."
			upload_failed=1
		else
			local new_att_id
			new_att_id=$(echo "$upload_output" | jq -r '.attachments[-1].id // empty' 2>/dev/null)
			if [[ -n "$new_att_id" ]]; then
				new_attachment_ids="${new_attachment_ids}${new_att_id}
"
			fi
		fi
	fi

	rm -rf "$temp_dir"

	if [[ "$upload_failed" -eq 1 ]]; then
		if [[ -n "$new_attachment_ids" ]]; then
			log_info "Cleaning up partially uploaded attachments..."
			while IFS= read -r att_id; do
				[[ -z "$att_id" ]] && continue
				bw delete attachment "$att_id" --itemid "$item_id" >/dev/null 2>&1 || true
			done <<< "$new_attachment_ids"
		fi
		exit 1
	fi

	if [[ -n "$old_attachment_ids" ]]; then
		log_info "Removing old attachments..."
		while IFS= read -r att_id; do
			[[ -z "$att_id" ]] && continue
			bw delete attachment "$att_id" --itemid "$item_id" >/dev/null 2>&1 || true
		done <<< "$old_attachment_ids"
	fi

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

	local temp_dir="$SECRETS_DIR/.sync_tmp"
	local backup_dir="$SECRETS_DIR/.sync_backup"
	rm -rf "$temp_dir" "$backup_dir"
	mkdir -p "$temp_dir"

	local existing_trap
	existing_trap=$(trap -p EXIT | sed "s/trap -- '//;s/' EXIT//")
	cleanup_temp() {
		rm -rf "$temp_dir" "$backup_dir"
		if [[ -n "$existing_trap" ]]; then
			eval "$existing_trap"
		fi
	}
	trap cleanup_temp EXIT INT TERM

	local success_count=0
	while IFS= read -r att; do
		[[ -z "$att" ]] && continue
		local att_id att_name
		att_id=$(echo "$att" | jq -r '.id')
		att_name=$(echo "$att" | jq -r '.fileName')
		log_info "Downloading $att_name..."
		if ! bw get attachment "$att_id" --itemid "$item_id" --output "$temp_dir/$att_name" >/dev/null; then
			log_error "Failed to download $att_name — aborting. Original files preserved."
			exit 1
		fi
		if [[ "$att_name" != ".manifest" ]]; then
			chmod 600 "$temp_dir/$att_name"
			success_count=$((success_count + 1))
		fi
	done <<< "$attachments"

	if [[ -d "$SECRETS_DIR" ]]; then
		mkdir -p "$backup_dir"
		find "$SECRETS_DIR" -maxdepth 1 -type f -exec cp {} "$backup_dir/" \;
	fi

	if [[ -f "$temp_dir/.manifest" ]]; then
		while IFS=$'\t' read -r safe_name rel_path; do
			[[ -z "$safe_name" || -z "$rel_path" ]] && continue
			if [[ -f "$temp_dir/$safe_name" ]]; then
				local dest_dir
				dest_dir="$SECRETS_DIR/$(dirname "$rel_path")"
				mkdir -p "$dest_dir"
				mv -f "$temp_dir/$safe_name" "$SECRETS_DIR/$rel_path"
			fi
		done < "$temp_dir/.manifest"
	else
		log_warning "No manifest found — files will use attachment names (subdirectory paths cannot be restored)."
		while IFS= read -r -d '' file; do
			local filename
			filename=$(basename "$file")
			mv -f "$file" "$SECRETS_DIR/$filename"
		done < <(find "$temp_dir" -type f -print0)
	fi

	rm -rf "$temp_dir" "$backup_dir"
	trap - EXIT INT TERM

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
