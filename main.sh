#!/bin/bash

WORKDIR="$HOME/.config/olit"
LISTENDIR="$WORKDIR/listeners"
DBFILE="$WORKDIR/dbfile"
CURFILE="$WORKDIR/current"
PROGNAME="olit"

# GENERAL UTILITIES ############################################################

fail() {
    echo "$PROGNAME: $@" 1>&2
    exit 1
}

is_valid_task() {
    # Must be alphanumeric with possible dashes  and underscores but must
    # contain at least one character.
    if [[ $1 =~ [a-zA-Z]+ ]]; then
        if [[ $1 =~ ^[a-zA-Z0-9_-]+$ ]]; then
            return 0
        fi
    fi
    return 1
}

is_quantifier() {
    if [[ $1 =~ ^: ]]; then
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

cleanup() {
    local maybe_pipe="$LISTENDIR/$$"
    [[ -p $maybe_pipe ]] && rm "$maybe_pipe"
}

# HELPER FUNCTIONS #############################################################

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

query_cmd() {
    local task="$1"
    shift
    local param="$1"
    quantifier="${param%%=*}"
    local quantity
    if [[ $param =~ = ]]; then
        quantity="${param##*=}"
    else
        quantity="$2"
    fi

    local lower
    local upper

    case "$quantifier" in
        :today)
            lower=$(date --date="00:00:00" +%s)
            upper=$(date --date="00:00:00 +1 day" +%s)
            ;;
        :this-month)
            quantity=$(date +%Y-%m-01)
            lower=$(date --date=$quantity +%s)
            upper=$(date --date="$quantity +1 month" +%s)
            ;;
        :day)
            lower=$(date --date=$quantity +%s)
            upper=$(date --date="$quantity +1 day" +%s)
            ;;
        :month)
            lower=$(date --date=${quantity}-01 +%s)
            upper=$(date --date="${quantity}-01 +1 month" +%s)
            ;;
        :ever)
            # Can't make it properly unbounded without introducing another
            # query script. These bounds seem reasonable for now.
            lower=0
            upper=$(date --date=2100-01-01 +%s)
            ;;
        *)
            fail "invalid quantifier: $quantifier"
    esac

    # catting the file into awk is not necessary but the file
    # might be visually lost when appended to the script block.
    cat "$DBFILE" |
        awk -F: "
\$1 == \"$task\" && \$2 >= $lower && \$3 < $upper {
    sum += \$3 - \$2
}

END {
    printf(\"$task: %s\n\", format_duration(sum))
}

function format_duration(secs,   s,m,h) {
    if (secs < 60) {
        return sprintf(\"%ds\", secs)
    }

    s = secs % 60
    m = (secs / 60) % 60

    if (secs < 3600) {
        return sprintf(\"%dm%ds\", m, s)
    } else {
        h = secs / 3600
        return sprintf(\"%dh%dm%ds\", h, m, s)
    }
}"

}

# PROCESSING STARTS HERE #######################################################

PROGNAME=$(basename "$0")

[[ -d $WORKDIR ]] || mkdir -p "$WORKDIR"

[[ $# -eq 0 ]] && fail "no operation specified"

# Enforce cleanup on program exit
trap cleanup EXIT

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
    query)
        query_cmd $@
        ;;
    *)
        fail "not implemented: $cmd"
        ;;
esac
