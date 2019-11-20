#!/bin/bash

# NB: This file will be copied to the remarkable tablet to be run there.

getRemarkablePathOfLastChangedDocument() {
    ls -1trd .local/share/remarkable/xochitl/????????-????-????-????-???????????? | tail -1

    # not sure how to get the latest "viewed" page
    #local f
    #local i
    #f=$(ls -tr1d .local/share/remarkable/xochitl/*-???????????? | tail -1)
    #i=$(cd "$f".cache && ls -tr1 *.* | tail -1 | sed 's@\..*$@@g')
    #echo "$f/$i.rm"
}


log() {
    echo "$@" 1>&2
}


SELF=$$
log SELF=$SELF

log $@

ps | \grep 'on\-remarkable' | awk '{ print $1 }' | \grep -v "^$$\$" | awk '{print $1}' | xargs kill

last=$(mktemp)
now=$(mktemp)
err=$(mktemp)
lastsize=0
livep=-1

cleanup() {
  # force self destruction
  ps | \grep 'on\-remarkable' | awk '{ print $1 }' | xargs kill
}
trap cleanup EXIT


log $last

sendpageinfo() {
  echo PAGE
  echo "$1"
  echo "$2"
}
sendnopdf() {
  echo NOPDF
}
sendpdf() {
  # TODO handle rotated pdf
  echo PDF
  wc -c < "$1"
  cat "$1"
  echo END
}
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
sendnoannotations() {
  echo NOANNOTATIONS
}

watchjournalctl() {
  journalctl -f \
  | awk '/ Page changed to / { print(gensub(/^.* Page changed to ([0-9]+) .*$/, "\\1", "g"))}
         / loading path: ".home./ { print(gensub(/^.*([.]local\/share\/remarkable\/xochitl\/[^.\/]+).*$/, "\\1", "g")) }  '  \
  | while read p ; do
    case "$p" in
      .local/*) echo $p > /tmp/liveview-uuid ;;
      *)        echo $p > /tmp/liveview-page ;;
    esac
  done
}
rm -f /tmp/liveview-uuid
rm -f /tmp/liveview-page


p=""

sha=$(cat $0 | sha1sum | sed 's@ .*@@g')
log $0
log $sha
log $2
if test \! "$sha" = "$2" ; then
  exit 123
  # trigger re-scp
fi

if test -f /etc/xdg/QtProject/qtlogging.ini ; then
  if grep -q 'xochitl.documentworker.debug=true' /etc/xdg/QtProject/qtlogging.ini ; then
    echo "##### already set for logging page change"
  else
    echo "##### log config present but no page change logging"
  fi
else
  echo "##### SETTING DEBUG LOGS TO DETECT PAGE CHANGE"
  mkdir -p /etc/xdg/QtProject
  printf "[Rules]\nxochitl.documentworker.debug=true\n" >> /etc/xdg/QtProject/qtlogging.ini
fi


watchjournalctl &

log $1
log $p
#sendfull "$p"

while true ; do
    if test "$1" = "//" ; then
      if test -f /tmp/liveview-page ; then
        pnum=$(cat /tmp/liveview-page)
        rm -f /tmp/liveview-page
        if test -f /tmp/liveview-uuid ; then
          uuidpath="$(cat /tmp/liveview-uuid)"
          rm -f /tmp/liveview-uuid
        else
          uuidpath="$(getRemarkablePathOfLastChangedDocument)"
        fi
        pname=$(cat $uuidpath.content | awk -v P=$pnum '/"pages"/ {go=1; p=0; next} go && p==P {print; exit} go {p=p+1}' | sed -e 's@^[^"]*"@@g' -e 's@"[^$]*$@@g')
        newp="$uuidpath/$pname.rm"
        log NEWP:$newp
      fi
      if test "$newp" \!= "$p" ; then
        sendnoannotations
        p="$newp"
        lastsize=0
        f=$(dirname "$p")
        log $f $lastf
        if test \! -f "$f.pdf" ; then
          sendnopdf
          lastf=""
          livep=-1
        elif test "$f" \!= "$lastf"; then
          sendpdf "$f.pdf"
          lastf="$f"
          livep=-1
        fi
        sendpageinfo "$pnum" "$p"
      fi
    fi
    if test \! -f "$p" ; then
      true
    elif test \! "$p" -ot "$last" -o "$lastsize" = 0 ; then
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
