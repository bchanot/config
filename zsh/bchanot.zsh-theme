# bchanot.zsh-theme — oh-my-zsh port of the bashrc prompt:
#   ✔ (12ms) user [ ~/dir ] [branch -*+] >
# Mark + timer cyan (red ✘ on failure), user and brackets green (red for root),
# git segment blue. Deployed to ~/.oh-my-zsh/custom/themes by install.sh.

zmodload zsh/datetime
autoload -Uz add-zsh-hook

# Git segment, same rules as parse_git_branch/parse_git_dirty in the bashrc:
# " [branch bits]" with + (new, modified, renamed or untracked files),
# * (ahead of upstream) and - (deleted files). Empty outside a repo.
bchanot_git_info() {
	local lines branch bits=''
	lines="$(git status --porcelain --branch 2>/dev/null)" || return 0
	branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || branch='(detached)'
	if print -r -- "$lines" | grep -qE '^(\?\?|[MAR].|.M)'; then
		bits='+'
	fi
	if print -r -- "${lines%%$'\n'*}" | grep -q '\[ahead '; then
		bits="*$bits"
	fi
	if print -r -- "$lines" | grep -qE '^(D.|.D)'; then
		bits="-$bits"
	fi
	print -r -- " [${branch}${bits:+ $bits}]"
}

# Command timer: preexec stamps the start, precmd formats the elapsed time with
# the bashrc's rules (about 3 significant digits, us up to h).
bchanot_timer_start() {
	_bchanot_cmd_start=$EPOCHREALTIME
}

bchanot_timer_stop() {
	integer delta_us us ms s m h
	(( delta_us = (EPOCHREALTIME - ${_bchanot_cmd_start:-$EPOCHREALTIME}) * 1000000 ))
	(( us = delta_us % 1000, ms = (delta_us / 1000) % 1000 ))
	(( s = (delta_us / 1000000) % 60, m = (delta_us / 60000000) % 60 ))
	(( h = delta_us / 3600000000 ))
	if ((h > 0)); then _bchanot_timer_show=${h}h${m}m
	elif ((m > 0)); then _bchanot_timer_show=${m}m${s}s
	elif ((s >= 10)); then _bchanot_timer_show=${s}.$((ms / 100))s
	elif ((s > 0)); then _bchanot_timer_show=${s}.$(printf %03d $ms)s
	elif ((ms >= 100)); then _bchanot_timer_show=${ms}ms
	elif ((ms > 0)); then _bchanot_timer_show=${ms}.$((us / 100))ms
	else _bchanot_timer_show=${us}us
	fi
	unset _bchanot_cmd_start
}

add-zsh-hook preexec bchanot_timer_start
add-zsh-hook precmd bchanot_timer_stop

PROMPT='%B%(?.%F{cyan}✔.%F{red}✘) (${_bchanot_timer_show}) '
PROMPT+='%(!.%F{red}.%F{green})%n [%f%b %~ %B%(!.%F{red}.%F{green})]'
PROMPT+='%F{blue}$(bchanot_git_info) %f%b> '
RPROMPT=''
