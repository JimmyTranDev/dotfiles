#!/bin/zsh
# ===================================================================
# csv_sorter.sh - CSV Commonness Score Sorter
# ===================================================================
# 
# A script to sort CSV files by commonness score, with interactive
# file selection from ranked words directories.

# Set strict mode
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored message
print_color() {
  local color="$1"; shift
  echo -e "${color}$*${NC}"
}

# Check if required tools are available
check_tool() {
  local tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    print_color "$RED" "Error: Required tool '$tool' not found."
    return 1
  fi
  return 0
}

# Find CSV files in ranked words directories
find_csv_files() {
  local search_dirs=(
    "$HOME/Programming/massvocabulary/old2/3/2_ranked_words"
    "$HOME/Programming/massvocabulary/old2/3/3_sorted_words"
    "$HOME/Programming/massvocabulary/massvocabulary-cli-old/src/data/2_ranked_words"
  )
  
  local csv_files=()
  
  for dir in "${search_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' file; do
        csv_files+=("$file")
      done < <(find "$dir" -name "*.csv" -type f -print0 2>/dev/null)
    fi
  done
  
  printf '%s\n' "${csv_files[@]}"
}

# Sort CSV file by commonness score
sort_csv_by_commonness_score() {
  local csv_file="$1"
  
  if [[ ! -f "$csv_file" ]]; then
    print_color "$RED" "Error: File does not exist: $csv_file"
    return 1
  fi
  
  print_color "$CYAN" "🔄 Sorting words by commonness score..."
  
  # Create temporary file for processing
  local temp_file=$(mktemp)
  local temp_sorted=$(mktemp)
  
  # Read CSV and extract word,score pairs
  {
    # First, read the header
    head -n1 "$csv_file"
    
    # Then process the data rows
    tail -n+2 "$csv_file" | while IFS= read -r line; do
      # Skip empty lines
      [[ -z "$line" ]] && continue
      
      # Parse CSV line - assuming format: word,commonness_score,...
      local word=$(echo "$line" | cut -d',' -f1 | tr -d '"' | xargs)
      local score_field=$(echo "$line" | cut -d',' -f2 | tr -d '"' | xargs)
      
      # Skip if word is empty or score is not a number
      if [[ -n "$word" && "$score_field" =~ ^[0-9]+$ ]]; then
        echo "$score_field,$line"
      fi
    done | sort -t',' -k1,1nr | cut -d',' -f2-
  } > "$temp_sorted"
  
  # Check if we have valid data
  if [[ $(wc -l < "$temp_sorted") -le 1 ]]; then
    print_color "$YELLOW" "Warning: No valid data found to sort in $csv_file"
    rm "$temp_file" "$temp_sorted"
    return 1
  fi
  
  # Backup original file
  cp "$csv_file" "${csv_file}.backup"
  
  # Write sorted results back to original file
  mv "$temp_sorted" "$csv_file"
  rm "$temp_file"
  
  # Get statistics
  local total_lines=$(( $(wc -l < "$csv_file") - 1 ))
  local first_score=$(tail -n+2 "$csv_file" | head -n1 | cut -d',' -f2 | tr -d '"' | xargs)
  local last_score=$(tail -n1 "$csv_file" | cut -d',' -f2 | tr -d '"' | xargs)
  local first_word=$(tail -n+2 "$csv_file" | head -n1 | cut -d',' -f1 | tr -d '"' | xargs)
  local last_word=$(tail -n1 "$csv_file" | cut -d',' -f1 | tr -d '"' | xargs)
  
  print_color "$GREEN" "✅ Words automatically sorted by commonness score"
  print_color "$BLUE" "   📊 Total words: $total_lines"
  if [[ -n "$first_score" && -n "$last_score" ]]; then
    print_color "$BLUE" "   📈 Highest score: $first_score ($first_word)"
    print_color "$BLUE" "   📉 Lowest score: $last_score ($last_word)"
  fi
  print_color "$YELLOW" "   💾 Backup saved as: ${csv_file}.backup"
}

# Interactive file selection using fzf
select_csv_file() {
  local csv_files=()
  while IFS= read -r line; do
    csv_files+=("$line")
  done < <(find_csv_files)
  
  if [[ ${#csv_files[@]} -eq 0 ]]; then
    print_color "$RED" "No CSV files found in ranked words directories."
    print_color "$YELLOW" "Searched directories:"
    print_color "$YELLOW" "  - ~/Programming/massvocabulary/old2/3/2_ranked_words"
    print_color "$YELLOW" "  - ~/Programming/massvocabulary/old2/3/3_sorted_words"
    print_color "$YELLOW" "  - ~/Programming/massvocabulary/massvocabulary-cli-old/src/data/2_ranked_words"
    return 1
  fi
  
  if check_tool fzf; then
    # Use fzf for interactive selection
    local selected_file
    selected_file=$(printf '%s\n' "${csv_files[@]}" | fzf \
      --prompt="Select CSV file to sort: " \
      --preview="echo 'File: {}'; echo; head -10 {}" \
      --preview-window=right:50% \
      --height=80% \
      --reverse)
    
    if [[ -n "$selected_file" ]]; then
      echo "$selected_file"
    else
      print_color "$YELLOW" "No file selected."
      return 1
    fi
  else
    # Fallback to numbered selection
    print_color "$CYAN" "Available CSV files:"
    for i in "${!csv_files[@]}"; do
      local file="${csv_files[$i]}"
      local basename_file=$(basename "$file")
      local dirname_file=$(dirname "$file" | sed "s|$HOME|~|")
      echo "$((i+1)). $basename_file (in $dirname_file)"
    done
    
    echo -n "Enter number (1-${#csv_files[@]}): "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#csv_files[@]}" ]]; then
      echo "${csv_files[$((selection-1))]}"
    else
      print_color "$RED" "Invalid selection."
      return 1
    fi
  fi
}

# Show help information
show_help() {
  cat << 'EOF'
CSV Commonness Score Sorter

USAGE:
  csv_sorter [file_path]

DESCRIPTION:
  Sort CSV files by commonness score (highest first). The script expects
  CSV files with 'word' and 'commonness_score' columns.

ARGUMENTS:
  file_path           Path to CSV file to sort (optional)
                      If not provided, interactive selection is used

OPTIONS:
  -h, --help         Show this help message

FEATURES:
  • Interactive file selection from ranked words directories
  • Automatic backup creation before sorting
  • Statistics display after sorting
  • Support for fzf enhanced selection (if available)

EXAMPLES:
  # Interactive selection
  csv_sorter

  # Sort specific file
  csv_sorter ~/path/to/words.csv

DIRECTORIES SEARCHED:
  • ~/Programming/massvocabulary/old2/3/2_ranked_words
  • ~/Programming/massvocabulary/old2/3/3_sorted_words  
  • ~/Programming/massvocabulary/massvocabulary-cli-old/src/data/2_ranked_words

EOF
}

# Main function
main() {
  local csv_file="${1:-}"
  
  case "$csv_file" in
    -h|--help|help)
      show_help
      return 0
      ;;
    "")
      # Interactive mode
      print_color "$CYAN" "CSV Commonness Score Sorter"
      print_color "$CYAN" "==========================="
      echo
      
      csv_file=$(select_csv_file) || return 1
      ;;
    *)
      # File provided as argument
      if [[ ! -f "$csv_file" ]]; then
        print_color "$RED" "Error: File not found: $csv_file"
        return 1
      fi
      ;;
  esac
  
  print_color "$YELLOW" "Selected file: $(basename "$csv_file")"
  print_color "$YELLOW" "Full path: $csv_file"
  echo
  
  # Confirm before processing
  echo -n "Sort this CSV file by commonness score? [Y/n]: "
  read -r confirm
  
  if [[ "$confirm" =~ ^[Nn] ]]; then
    print_color "$YELLOW" "Operation cancelled."
    return 0
  fi
  
  # Sort the file
  sort_csv_by_commonness_score "$csv_file"
}

# Run main function with all arguments
main "$@"