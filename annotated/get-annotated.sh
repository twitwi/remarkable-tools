#!/bin/bash

W=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

PDFTK=$(which pdftk || echo "java -jar $W/deps/pdftk-all.jar")
RMAPI=$(which rmapi || echo "$HOME/go/bin/rmapi")
RM2SVG="python3 $W/../liveview/rm2svg.py"

direct_download () {
    false
}

# Dependencies
# * rsvg-convert
# * ps2pdf
# * pdfinfo
# * pdfjam
# * TODO update?
# * rmapi https://github.com/juruen/rmapi
# * rM2svg https://github.com/reHackable/maxio/blob/master/tools/rM2svg
# * pdfunite
# * pdftk
# * pdftoppm (if you use cropping)

set -o errexit


function die_with_usage() {
  echo "Usage: rm-dl-annotated path/to/cloud/PDF"
  exit 1
}
function LOG() {
    "$@" 2>&1 | sed 's@^@>>> @g'
    return ${PIPESTATUS[0]}
}

# Check arguments

if [ "$#" -ne 1 ]; then
  die_with_usage
fi

# Do our work in a temporary directory
workdir=$(mktemp -d)
remotepath="$1"
name=$(basename "$remotepath")
shift

# Lazy generic parameter reading
for i in "$@" ; do
    if echo "$i" | grep -q '=' ; then
        eval "$i"
    fi
done

pushd "$workdir"

# Download the given document using the ReMarkable Tablet or Cloud API
if direct_download ; then
    echo "TODO"
else
    LOG $RMAPI get "$remotepath"
    unzip "$name.zip" >/dev/null

    UUID=$(basename "$(LOG ls ./*-*-*.pdf)" .pdf)

    if [ "$UUID" = "" ] ; then
        NOPDF=true
        UUID=$(basename "$(ls ./*-*-*.pagedata)" .pagedata)
        echo "Not using pdf then"
    fi

    if LOG ls "./$UUID/"*.rm ; then
        echo "Found annotations"
    else
        echo "PDF is not annotated. Exiting."
        #rm -r "$WORK_DIR"
        exit 0
    fi
fi


# DELETED things about transform and crop...

# Generating the annotation pdf
if [ "$NOPDF" = true ] ; then
    npages=$(ls -1 "./$UUID/"*.rm | wc -l)
else
    npages=$(pdfinfo "./$UUID.pdf" | grep '^Pages:'|awk '{print $2}')
    maybe_rotate() {
        local wh
        wh=$(pdfinfo "./$UUID.pdf" | grep '^Page size:')
        wh="${wh#*: }"
        wh="${wh%pts*}"
        w=${wh% x*}
        h=${wh#*x }
        if [ "$w" -gt "$h" ] ; then
            echo 'true'
        else
            echo 'false'
        fi
    }
    rotate=$(maybe_rotate)
fi

annotated_pages=()
montage=()
echo "" | ps2pdf -sPAPERSIZE=a5 - empty.pdf

for (( i=0 ; i<$npages ; i++ )) ; do 

  if LOG ls -l1 "./$UUID/$i.rm" ; then
      $RM2SVG -c -i ./$UUID/$i.rm -o $i.svg
      rsvg-convert -f pdf -o "$i.pdf" "$i.svg"
      if grep -q '<polyline' "$i.svg" ; then
          # remember only if there are some paths generated
          annotated_pages+=( $(($i + 1)) )
      fi
      montage+=("$i.pdf")
  else
      echo "... so adding an empty annotation page"
      montage+=(empty.pdf)
  fi
done
if [ "$rotate" = true ] ; then
    pdftk "${montage[@]}" cat output "$UUID"_annotations_torotate.pdf
    pdftk "$UUID"_annotations_torotate.pdf cat 1-endeast output "$UUID"_annotations.pdf
    #pdftk "${montage[@]}" cat output "$UUID"_annotations.pdf
else
    pdftk "${montage[@]}" cat output "$UUID"_annotations.pdf
fi




# Layer the annotations onto the original PDF
OUTPUT_PDF="$name-annotated.pdf"
OUTPUT_PDF2="$name-annotated-only.pdf"

if [ "$NOPDF" = true ] ; then
    popd >/dev/null
    cp "$workdir"/"$UUID"_annotations.pdf ./"$OUTPUT_PDF"
    echo Generated "\"$OUTPUT_PDF\""
    exit 0
fi
    
#echo "extending original pdf"
#pdfjam "$UUID".pdf --papersize '{1404pt,1872pt}' --trim '0 0 -13mm 0' --clip 'true' --outfile "$UUID"-extend.pdf
#pdfjam "$UUID".pdf --papersize '{1404pt,1872pt}' --clip 'true' --outfile "$UUID"-extend.pdf
if [ "$rotate" = true ] ; then
    LOG pdfjam "$UUID".pdf --papersize '{1872pt,1404pt}' --trim '-8mm 0 0 0' --clip 'true' --outfile "$UUID"-extend.pdf
else
    LOG pdfjam "$UUID".pdf --papersize '{1404pt,1872pt}' --trim '0 -8mm 0 0' --clip 'true' --outfile "$UUID"-extend.pdf
fi

echo "Stamping pdf"
pdftk "$UUID"-extend.pdf multistamp "$UUID"_annotations.pdf output "$OUTPUT_PDF"

echo "Producing a restricted version (with only annotated pages)"
if [ "${#annotated_pages[@]}" = 0 ] ; then
    cp empty.pdf "$OUTPUT_PDF2"
else
    pdftk "$OUTPUT_PDF" cat ${annotated_pages[@]} output "$OUTPUT_PDF2"
fi

popd >/dev/null
cp "$workdir"/"$OUTPUT_PDF" .
cp "$workdir"/"$OUTPUT_PDF2" .

echo "--- OK ---"
#rm -r "$workdir"
echo NB: Not removing $workdir

echo Generated "\"$OUTPUT_PDF\""
echo Generated "\"$OUTPUT_PDF2\"" "(${#annotated_pages[@]} pages)"
