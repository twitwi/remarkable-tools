#!/bin/bash

# NB: This file will be copied to the remarkable tablet to be run there.

getRemarkablePathOfLastEditedPage() {
    ls -1tr .local/share/remarkable/xochitl/*/*.rm | tail -1
}

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

if test "$1" = "//" ; then
  p=$(getRemarkablePathOfLastEditedPage)
else
  p="$1"
fi

sha=$(cat $0 | sha1sum | sed 's@ .*@@g')
log $0
log $sha
log $2
if test \! "$sha" = "$2" ; then
  exit 123
  # trigger re-scp
fi

log $1
log $p
sendit "$p"

while true ; do
    if test \! "$p" -ot "$last" ; then
        size=$(cat "$p" | wc -c)
        if test "$size" -gt "$lastsize" -o "$size" -lt 100 ; then
            lastsize=$size
            touch "$last"
            sendit "$p"
        fi
    else
        # show liveliness + trigger auto-kill on disconnection
        printf '\b\b%s' $(( $RANDOM % 100 )) >&2
        # wait for 0.1 second
        read -t .1
    fi
done
