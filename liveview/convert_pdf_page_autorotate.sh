#!/bin/bash


pdf="$1"
page="$2"
out="$3"

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
#run_cmd('convert', '-density', '300', file_pdf+'['+page+']', '-resize', 'x1404', '-extent', 'x-55', file_svg+'.png')
#print('convert', file_pdf+'['+page+']', file_svg+'.png')
go convert -density 200 "$pagepath" $rotate $tr "$out"
