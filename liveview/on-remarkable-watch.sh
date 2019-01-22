#!/bin/bash

# NB: This file will be copied to the remarkable tablet to be run there.

log() {
    echo "$@" 1>&2
}

log $@
#ps aux |\grep 'on\-remarkable'|\grep -v -e "$2" |awk '{print $1}'|xargs kill

last=$(mktemp)
lastsize=0
log $last

sendit() {
        echo START
        wc -c < "$1"
        cat "$1"
        echo END
}

sendit "$1"

while true ; do
    if test \! "$1" -ot "$last" ; then
        size=$(cat "$1" | wc -c)
        if test "$size" -gt "$lastsize" -o "$size" -lt 100 ; then
            lastsize=$size
            touch "$last"
            sendit "$1"
        fi
    else
        # show liveliness + trigger auto-kill on disconnection
        printf '\b\b%s' $(( $RANDOM % 100 )) >&2
        # wait for 0.1 second
        read -t .1
    fi
done
