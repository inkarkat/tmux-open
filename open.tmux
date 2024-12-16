#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# shellcheck source=./scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"

default_open_key="o"
open_option="@open"

default_open_editor_key="C-o"
open_editor_option="@open-editor"
open_editor_override="@open-editor-command"

default_open_viewer_key="C-l"
open_viewer_option="@open-viewer"
open_viewer_override="@open-viewer-command"

open_opener_override="@open-opener-command"
open_searcher_override="@open-searcher-command"

command_exists() {
	local command="$1"
	type "$command" >/dev/null 2>&1
}

is_osx() {
	[ "$(uname)" == "Darwin" ]
}

is_cygwin() {
	[[ "$(uname)" =~ CYGWIN ]]
}

command_generator() {
	local command_string="$1"
	echo "{ cd \"\$(tmux display-message -p '#{pane_current_path}')\" && tr '\\n' '\\0' | xargs -0I {} $command_string {} >/dev/null; }"
}

search_command_generator() {
	local command_string="${1:?}"; shift
	local engine="${1:?}"; shift

	echo "$command_string \"$engine\$(cat)\" >/dev/null"
}

generate_open_command() {
	local opener
	if opener="$(get_tmux_option "$open_opener_override" '')" && [ -n "${opener-}" ]; then
		command_generator "${opener}"
	elif is_osx; then
		command_generator "open"
	elif is_cygwin; then
		command_generator "cygstart"
	elif command_exists "xdg-open"; then
		command_generator "xdg-open"
	else
		# error command for Linux machines when 'xdg-open' not installed
		"$CURRENT_DIR/scripts/tmux_open_error_message.sh" "xdg-open"
	fi
}

generate_open_search_command() {
	local engine="${1:?}"; shift
	local opener
	if opener="$(get_tmux_option "$open_searcher_override" '')" && [ -n "${opener-}" ]; then
		search_command_generator "$opener" "$engine"
	elif is_osx; then
		search_command_generator "open" "$engine"
	elif is_cygwin; then
		search_command_generator "cygstart" "$engine"
	elif command_exists "xdg-open"; then
		search_command_generator "xdg-open" "$engine"
	else
		# error command for Linux machines when 'xdg-open' not installed
		"$CURRENT_DIR/scripts/tmux_open_error_message.sh" "xdg-open"
	fi
}

# 1. write a command to the terminal, example: 'vim some_file.txt'
# 2. invoke the command by pressing enter/C-m
generate_terminal_opener_command() {
	local default="${1:?}"; shift
	local override_config="${1:?}"; shift
	local terminal_command=$(get_tmux_option "$override_config" "$default")
	local literalHome="$HOME"
	literalHome="${literalHome//\\/\\\\}"
	literalHome="${literalHome//&/\\&}"
	echo "sed -e 's#^~/#${literalHome//#/\\#}/#' | tr '\\n' '\\0' | xargs -0I {} printf '%q\\n' {} | tmux send-keys -l \"$terminal_command \$(tr '\\n' ' ')\"; tmux send-keys 'C-m'"
}

set_copy_mode_open_bindings() {
	local open_command="$(generate_open_command)"
	local key_bindings=$(get_tmux_option "$open_option" "$default_open_key")
	local key; for key in $key_bindings; do
		bind_key_copy_mode "$key" copy-pipe-and-cancel "$open_command"
	done
}

set_copy_mode_open_editor_bindings() {
	local editor_command="$(generate_terminal_opener_command "${EDITOR:-vi}" "$open_editor_override")"
	local key_bindings="$(get_tmux_option "$open_editor_option" "$default_open_editor_key")"
	local key; for key in $key_bindings; do
		bind_key_copy_mode "$key" copy-pipe-and-cancel "$editor_command"
	done
}

set_copy_mode_open_viewer_bindings() {
	local viewer_command="$(generate_terminal_opener_command "${pager:-less}" "$open_viewer_override")"
	local key_bindings="$(get_tmux_option "$open_viewer_option" "$default_open_viewer_key")"
	local key; for key in $key_bindings; do
		bind_key_copy_mode "$key" copy-pipe-and-cancel "$viewer_command"
	done
}

set_copy_mode_open_search_bindings() {
	local stored_engine_vars="$(stored_engine_vars)" engine_var engine
	for engine_var in $stored_engine_vars; do
		engine="$(get_engine "$engine_var")" || continue
		bind_key_copy_mode "$engine_var" copy-pipe-and-cancel "$(generate_open_search_command "$engine")"
	done
}

main() {
	set_copy_mode_open_bindings
	set_copy_mode_open_editor_bindings
	set_copy_mode_open_viewer_bindings
	set_copy_mode_open_search_bindings
}

main
