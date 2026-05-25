# System-wide command logging for interactive shells

LOG_FILE="/var/log/shell_commands.log"

if [ -f "$LOG_FILE" ]; then
    # Bash logging setup
    if [ -n "$BASH_VERSION" ]; then
        log_bash_command() {
            local last_cmd
            last_cmd=$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//')
            # Only log if command is non-empty and not identical to the last logged one to avoid duplicate logging
            if [ -n "$last_cmd" ] && [ "$last_cmd" != "$LAST_LOGGED_CMD" ]; then
                echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') USER=$USER WORKSTATION=$HOSTNAME PID=$$: $last_cmd" >> "$LOG_FILE"
                export LAST_LOGGED_CMD="$last_cmd"
            fi
        }
        # Append to PROMPT_COMMAND if it doesn't already contain log_bash_command
        if [[ ! "$PROMPT_COMMAND" =~ "log_bash_command" ]]; then
            export PROMPT_COMMAND="log_bash_command; $PROMPT_COMMAND"
        fi
    fi

    # Zsh logging setup
    if [ -n "$ZSH_VERSION" ]; then
        log_zsh_command() {
            local last_cmd
            last_cmd=$(fc -ln -1)
            if [ -n "$last_cmd" ] && [ "$last_cmd" != "$LAST_LOGGED_CMD" ]; then
                echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') USER=$USER WORKSTATION=$HOSTNAME PID=$$: $last_cmd" >> "$LOG_FILE"
                export LAST_LOGGED_CMD="$last_cmd"
            fi
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd log_zsh_command
    fi
fi
