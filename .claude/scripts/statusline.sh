#!/bin/bash

# This script processes Claude Code statusline JSON input and:
# 1. Logs metadata and conversation history to LOG.txt
# 2. Displays a formatted statusline with model info and recent messages
# 3. Shows Git branch, token usage, and system stats

# Read JSON input from stdin (provided by Claude Code)
json_input=$(cat)

# ANSI Color codes for better formatting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[0;37m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# Calculate the absolute path to LOG.txt in the repository root
# This ensures the log file is always in the root directory regardless of where script is called from
log_file="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")/LOG.txt"

# Log the raw JSON metadata with timestamp for debugging/monitoring
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $json_input" >> "$log_file"

# Extract key fields from the JSON input using jq
# These fields are used both for logging and statusline display
model=$(echo "$json_input" | jq -r '.model.display_name // "Unknown"')
current_dir=$(echo "$json_input" | jq -r '.workspace.current_dir // "Unknown"')
session_id=$(echo "$json_input" | jq -r '.session_id // "Unknown"')
transcript_path=$(echo "$json_input" | jq -r '.transcript_path // ""')
output_style=$(echo "$json_input" | jq -r '.output_style // "standard"')
version=$(echo "$json_input" | jq -r '.version // "Unknown"')

# Get Git branch if in a git repository
git_branch=""
if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
    git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
fi

# Get system resource usage
mem_usage=""
cpu_load=""
if command -v free &> /dev/null; then
    mem_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
fi
if [[ -f /proc/loadavg ]]; then
    cpu_load=$(cut -d' ' -f1 /proc/loadavg)
fi

# Append only the last line from the transcript to LOG.txt
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    echo "" >> "$log_file"
    echo "=== LAST TRANSCRIPT LINE ===" >> "$log_file"
    
    # Get only the last line from the transcript and extract its message content
    tail -1 "$transcript_path" | jq -r '
        select(.message.role == "user" or .message.role == "assistant") |
        (if .message.content then
            if .message.content | type == "array" then
                # For array content (e.g., when assistant uses tools)
                .message.content | map(
                    if .text then .text
                    elif .content then .content
                    else ""
                    end
                ) | join("")
            elif .message.content | type == "string" then
                # For simple string content
                .message.content
            else
                ""
            end
        else
            "[no content]"
        end)
    ' 2>/dev/null >> "$log_file"
    
    echo "=== END TRANSCRIPT ===" >> "$log_file"
    echo "" >> "$log_file"
    
    # Add a greeting after each Claude request
    echo "" >> "$log_file"
fi

# Count messages and calculate session statistics
message_count=0
user_msg_count=0
assistant_msg_count=0
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    message_count=$(wc -l < "$transcript_path" 2>/dev/null || echo 0)
    user_msg_count=$(jq -r 'select(.message.role == "user") | .message.role' "$transcript_path" 2>/dev/null | wc -l || echo 0)
    assistant_msg_count=$(jq -r 'select(.message.role == "assistant") | .message.role' "$transcript_path" 2>/dev/null | wc -l || echo 0)
fi

# Extract recent messages for the statusline display
# This shows a preview of the last 2 messages in the actual statusline
recent_messages=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    # Get last 20 lines of transcript to find recent messages
    # Process with jq to extract and format message content
    recent_messages=$(tail -20 "$transcript_path" | \
        jq -r 'select(.message.role == "user" or .message.role == "assistant") | 
               "\(.message.role): " + 
               (if .message.content then 
                  (.message.content | 
                   # Handle array content (tool uses)
                   if type == "array" then 
                     (.[0].content // .[0].text // "no content") | 
                     if type == "string" then . else tostring end
                   else 
                     . 
                   end | 
                   # Clean up for statusline: remove newlines and truncate
                   gsub("\n"; " ") | 
                   if length > 30 then .[0:30] + "..." else . end)
                else 
                  "no content" 
                end)' 2>/dev/null | tail -2 | tr '\n' ' | ')
fi

# Try to extract token usage from the last assistant message
token_info=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    last_assistant=$(tac "$transcript_path" 2>/dev/null | grep -m1 '"role":"assistant"' || echo "")
    if [[ -n "$last_assistant" ]]; then
        # Check if usage information is available
        usage=$(echo "$last_assistant" | jq -r '.usage // empty' 2>/dev/null)
        if [[ -n "$usage" ]]; then
            input_tokens=$(echo "$usage" | jq -r '.input_tokens // 0')
            output_tokens=$(echo "$usage" | jq -r '.output_tokens // 0')
            total_tokens=$((input_tokens + output_tokens))
            token_info=" | Tokens: ${total_tokens}"
        fi
    fi
fi

# Environment variable for output mode customization
OUTPUT_MODE=${STATUSLINE_MODE:-"full"}  # Options: full, compact, minimal, debug

# Generate the statusline output based on mode
case "$OUTPUT_MODE" in
    "debug")
        # Debug mode: Show all available information
        echo "${BOLD}${CYAN}🔍 Debug${RESET} | Model: ${GREEN}$model${RESET} | Git: ${YELLOW}$git_branch${RESET} | Msgs: ${BLUE}U:$user_msg_count/A:$assistant_msg_count${RESET} | Mem: ${MAGENTA}$mem_usage${RESET} | Load: ${RED}$cpu_load${RESET}$token_info"
        ;;
    "minimal")
        # Minimal mode: Just model and git branch
        if [[ -n "$git_branch" ]]; then
            echo "${GREEN}$model${RESET} @ ${YELLOW}$git_branch${RESET}"
        else
            echo "${GREEN}$model${RESET}"
        fi
        ;;
    "compact")
        # Compact mode: Model, git, and message count
        git_info=""
        if [[ -n "$git_branch" ]]; then
            git_info=" | ${YELLOW}⎇ $git_branch${RESET}"
        fi
        echo "${BOLD}${CYAN}🤖${RESET} ${GREEN}$model${RESET}$git_info | ${BLUE}💬 $user_msg_count/$assistant_msg_count${RESET}"
        ;;
    "full"|*)
        # Full mode (default): Comprehensive statusline
        git_info=""
        if [[ -n "$git_branch" ]]; then
            git_info=" | ${YELLOW}⎇ $git_branch${RESET}"
        fi
        
        sys_info=""
        if [[ -n "$mem_usage" ]]; then
            sys_info=" | ${MAGENTA}Mem: $mem_usage${RESET}"
        fi
        if [[ -n "$cpu_load" ]]; then
            sys_info="$sys_info | ${RED}Load: $cpu_load${RESET}"
        fi
        
        echo "${BOLD}${CYAN}🤖 Claude${RESET} | ${GREEN}$model${RESET}$git_info | ${BLUE}💬 U:$user_msg_count A:$assistant_msg_count${RESET}$sys_info$token_info"
        ;;
esac
