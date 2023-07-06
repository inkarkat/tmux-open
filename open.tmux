#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# shellcheck source=./scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"

default_open_key="o"
open_option="@open"

default_open_editor_key="C-o"
open_editor_option="@open-editor"
open_editor_override="@open-editor-command"

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
	local command_string="$1"
	local engine="$2"

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
	local engine="$1"
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
	echo "tr '\\n' '\\0' | xargs -0I {} printf '%q\\n' {} | tmux send-keys -l \"$terminal_command \$(tr '\\n' ' ')\"; tmux send-keys 'C-m'"
}

set_copy_mode_open_bindings() {
	local open_command
	open_command="$(generate_open_command)"
	local key_bindings
	key_bindings=$(get_tmux_option "$open_option" "$default_open_key")
	local key
	for key in $key_bindings; do
		if tmux-is-at-least 2.4; then
			tmux bind-key -T copy-mode-vi "$key" send-keys -X copy-pipe-and-cancel "$open_command"
			tmux bind-key -T copy-mode    "$key" send-keys -X copy-pipe-and-cancel "$open_command"
		else
			tmux bind-key -t vi-copy    "$key" copy-pipe "$open_command"
			tmux bind-key -t emacs-copy "$key" copy-pipe "$open_command"
		fi
	done
}

set_copy_mode_open_editor_bindings() {
	local editor_command
	editor_command="$(generate_terminal_opener_command "${EDITOR:-vi}" "$open_editor_override")"
	local key_bindings
	key_bindings="$(get_tmux_option "$open_editor_option" "$default_open_editor_key")"
	local key
	for key in $key_bindings; do
		if tmux-is-at-least 2.4; then
			tmux bind-key -T copy-mode-vi "$key" send-keys -X copy-pipe-and-cancel "$editor_command"
			tmux bind-key -T copy-mode    "$key" send-keys -X copy-pipe-and-cancel "$editor_command"
		else
			tmux bind-key -t vi-copy    "$key" copy-pipe "$editor_command"
			tmux bind-key -t emacs-copy "$key" copy-pipe "$editor_command"
		fi
	done
}

set_copy_mode_open_search_bindings() {
	local stored_engine_vars
	stored_engine_vars="$(stored_engine_vars)"
	local engine_var
	local engine
	local key

	for engine_var in $stored_engine_vars; do
		engine="$(get_engine "$engine_var")" || continue

		if tmux-is-at-least 2.4; then
			tmux bind-key -T copy-mode-vi "$engine_var" send-keys -X copy-pipe-and-cancel "$(generate_open_search_command "$engine")"
			tmux bind-key -T copy-mode    "$engine_var" send-keys -X copy-pipe-and-cancel "$(generate_open_search_command "$engine")"
		else
			tmux bind-key -t vi-copy    "$engine_var" copy-pipe "$(generate_open_search_command "$engine")"
			tmux bind-key -t emacs-copy "$engine_var" copy-pipe "$(generate_open_search_command "$engine")"
		fi

	done
}

main() {
	set_copy_mode_open_bindings
	set_copy_mode_open_editor_bindings
	set_copy_mode_open_search_bindings
}

main
