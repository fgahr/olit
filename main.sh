#!/bin/bash

WORKDIR="$HOME/.config/olit"
LISTENDIR="$WORKDIR/listeners"
DBFILE="$WORKDIR/dbfile"
CURFILE="$WORKDIR/current"
PROGNAME="olit"

# HELPER FUNCTIONS #############################################################

fail() {
    echo "$PROGNAME: $@" 1>&2
    exit 1
}

is_valid_task() {
    if [[ $1 =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

has_current_task() {
    [[ ! -f $CURFILE ]] && return 1
    if [[ -n $(cat $CURFILE) ]]; then
        return 0
    else
        return 1
    fi
}

set_current() {
    local content="$1"
    echo "$content" > "$CURFILE"
    notify_listeners "started: "
    echo -n "started: " && print_current
}

stop_current() {
    has_current_task || return 1
    notify_listeners "stopped: "
    cat "$CURFILE" | sed -e "s/\$/:$(date +%s)/"
}

print_current() {
    has_current_task || fail "print_current: no current task"
    local content=$(cat "$CURFILE")
    local task="${content%%:*}"
    local started="${content##*:}"
    echo "${task} since $(date --rfc-3339=seconds --date=@$started)"
}

notify_listeners() {
    local message="$1"
    [[ -d $LISTENDIR ]] || return 0 # No listeners

    for pipe in $(find "$LISTENDIR" -type p); do
        # Still connected? If not, remove the pipe.
        local pid=$(basename "$pipe")
        ps --pid="$pid" | grep "$PROGNAME" > /dev/null || rm "$pipe"

        if [[ -p $pipe ]]; then
            echo -n "$message" >> "$pipe"
            print_current >> "$pipe"
        fi
    done
}

# COMMANDS #####################################################################

start_cmd() {
    [[ -z $1 ]] && fail "start: no task specified"
    local task="$1"
    if is_valid_task "$task"; then
        has_current_task && stop_cmd
        set_current "$task:$(date +%s)"
    else
        fail "start: invalid task name: $task"
    fi
}

stop_cmd() {
    has_current_task || fail "no active task"
    echo -n "stopped: "
    print_current
    stop_current >> "$DBFILE"
    echo -n "" > "$CURFILE"
}

current_cmd() {
    has_current_task || fail "no active task"
    echo -n "currently: "
    print_current
}

abort_cmd() {
    has_current_task || fail "no active task"
    echo -n "aborted: "
    print_current
    notify_listeners "aborted: "
    echo -n "" > "$CURFILE"
}

listen_cmd() {
    [[ -d $LISTENDIR ]] || mkdir -p "$LISTENDIR"
    local pipe="$LISTENDIR/$$"
    has_current_task && echo -n "current: " && print_current
    mkfifo -m 600 "$pipe"
    while true; do
        cat "$pipe"
    done
    rm "$pipe"
}

# PROCESSING STARTS HERE #######################################################

PROGNAME=$(basename "$0")

[[ -d $WORKDIR ]] || mkdir -p "$WORKDIR"

[[ $# -eq 0 ]] && fail "no operation specified"

cmd="$1"
shift

case "$cmd" in
    start)
        start_cmd $@
        ;;
    stop)
        stop_cmd
        ;;
    current)
        current_cmd
        ;;
    abort)
        abort_cmd
        ;;
    listen)
        listen_cmd
        ;;
    *)
        fail "not implemented: $cmd"
        ;;
esac
