#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

generate_fms_export() {
    local dir="${1:-.}"
    local no_file="$dir/src/fms-fallbacks/fallback-no.json"
    local en_file="$dir/src/fms-fallbacks/fallback-en.json"

    if [[ ! -f "$no_file" ]] || [[ ! -f "$en_file" ]]; then
        log_error "FMS fallback files not found in $dir/src/fms-fallbacks/"
        exit 1
    fi

    local new_keys
    new_keys=$(git diff HEAD --unified=0 -- "$no_file" "$en_file" \
        | grep '^+' \
        | grep -v '^+++' \
        | sed -n 's/^+[[:space:]]*"\([^"]*\)":.*/\1/p' \
        | sort -u)

    if [[ -z "$new_keys" ]]; then
        log_warning "No new FMS keys found in git diff"
        exit 0
    fi

    local outfile="$dir/fms.json"

    python3 -c "
import json, sys

keys = sys.stdin.read().strip().split('\n')
no = json.load(open('$no_file'))
en = json.load(open('$en_file'))

result = [{'key': k, 'no': no.get(k, ''), 'en': en.get(k, '')} for k in keys]

with open('$outfile', 'w') as f:
    json.dump(result, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(len(result))
" <<< "$new_keys"

    local count
    count=$(wc -l <<< "$new_keys" | tr -d ' ')
    log_success "Generated $outfile with $count new keys"
}

generate_fms_export "${1:-.}"
