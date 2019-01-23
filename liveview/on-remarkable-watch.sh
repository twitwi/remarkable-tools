#!/bin/bash

# NB: This file will be copied to the remarkable tablet to be run there.

getRemarkablePathOfLastEditedPage() {
    ls -1tr .local/share/remarkable/xochitl/*/*.rm | tail -1
}

log() {
    echo "$@" 1>&2
}

log $@
ps | \grep 'on\-remarkable' | awk '{ print $1 }' | \grep -v "^$$\$" | awk '{print $1}' | xargs kill

last=$(mktemp)
now=$(mktemp)
err=$(mktemp)
lastsize=0
log $last

sendfull() {
  echo FULL
  wc -c < "$1"
  cat "$1"
  echo END
}
sendpatch() {
  echo PATCH
  echo "$diff"
  if \grep -q -e "$3" "$2" ; then
    echo APPEND
    local s
    s=$(( $6 - $5 ))
    echo $s
    tail -c -$s "$4"
  fi
  if \grep -q -e "$4" "$2" ; then
    echo TRUNC
    echo $6
  fi
  echo END
}
sendauto() { # "$diff" "$err_f" "$last_f" "$now_f" "$lastsize" "$size"
  if test "$1" = "" -o "$5" = 0 ; then
    sendfull "$4"
  elif test $(echo "$1" | wc -l) = 100 ; then
    sendfull "$4"
  else
    sendpatch "$@"
  fi
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
#sendfull "$p"

while true ; do
    if test \! "$p" -ot "$last" -o "$lastsize" = 0 ; then
        size=$(wc -c < "$p")
        if test "$size" -ne "$lastsize" ; then
          cp "$p" "$now"
          size=$(wc -c < "$now")
          diff=$(cmp -l "$last" "$now" 2> "$err" | head -n 100)
          sendauto "$diff" "$err" "$last" "$now" "$lastsize" "$size"

          cp "$now" "$last"
          lastsize=$size
        fi
    else
        # show liveliness + trigger auto-kill on disconnection
        printf '\b\b%s' $(( $RANDOM % 100 )) >&2
        # wait for 0.1 second
        read -t .1
    fi
done
