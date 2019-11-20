#!/bin/bash

WORKDIR="$HOME/.config/olit"
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

print_current() {
    local content=$(cat "$CURFILE")
    local task="${content%%:*}"
    local started="${content##*:}"
    echo "${task} since $(date --rfc-3339=seconds --date=@$started)"
}

# COMMANDS #####################################################################

start_cmd() {
    [[ -z $1 ]] && fail "start: no task specified"
    local task="$1"
    if is_valid_task "$task"; then
        if has_current_task; then
            stop_cmd
        fi
        echo "$task:$(date +%s)" > "$CURFILE"
    else
        fail "start: invalid task name: $task"
    fi
}

stop_cmd() {
    has_current_task || fail "no active task"
    echo -n "stopped: "
    print_current
    cat "$CURFILE" | sed -e "s/\$/:$(date +%s)/" >> "$DBFILE"
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
    echo -n "" > "$CURFILE"
}

# PROCESSING STARTS HERE #######################################################

PROGNAME="$0"

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
    *)
        fail "not implemented: $cmd"
        ;;
esac
