#!/bin/bash


pdf="$1"
page="$2"
out="$3"

which convert || {
  cp "${out%/*}/convert-missing.${out##*.}" "${out}"
  exit
}

pagepath="$pdf[$2]"
#echo $pagepath
inf=$(identify "$pagepath")
echo $inf
wh=$(echo "$inf" | sed 's@.* PDF \([0-9]*x[0-9]*\) .*@\1@')
echo $wh
w=${wh%x*}
h=${wh#*x}
echo $w $h

ow=1404
oh=1872
rotate=

# we want to reason in portrait
if [ "$w" -gt "$h" ] ; then
  rotate="-rotate -90"
  tmp=$w
  w=$h
  h=$tmp
fi
echo $rotate $w $h

# where to put the margin?
echo  $(( $w * $oh )) -lt $(( $h * $ow ))
if [ $(( $w * $oh )) -lt $(( $h * $ow )) ] ; then
  tr="-resize x${oh}"
  #tr="-extent x-55"
else
  tr="-resize ${ow}x"
fi

go() {
  echo "$@"
  "$@"
}

go convert -density 200 "$pagepath" $rotate $tr -background white -flatten "$out"
