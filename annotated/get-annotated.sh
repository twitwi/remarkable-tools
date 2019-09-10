#!/bin/bash

W=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

D0="$0"
PDFTK=$(which pdftk || echo "java -jar $W/deps/pdftk-all.jar")
RMAPI=$(which rmapi || echo "$HOME/go/bin/rmapi")
RM2SVG="python3 $W/../liveview/rm2svg.py"

# Dependencies
# * rsvg-convert   (apt install librsvg2-bin)
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
  echo "Usage: $D0 <path/to/cloud/PDF>"
  echo "Usage: $D0 <path/to/cloud/PDF> cloud=true"
  echo "Usage: $D0 <UUID>"
  echo "Usage: $D0 update-metadata"
  echo "Usage: source <($D0 def-geta)"
  exit 1
}
function LOG() {
    "$@" 2>&1 | sed 's@^@>>> @g'
    return ${PIPESTATUS[0]}
}
function update_metadata_cache() {
    if [ "$#" -gt 0   -o   \! -f "$metadatacache" ] ; then
        ssh remarkable 'for i in .local/share/remarkable/xochitl/*.metadata ; do echo FILE: $i ; cat $i ; done' | tr -d '"' | sed -e 's@.local/.*/@@g' -e 's@\([.]metadata\|,\)$@@g' > "$metadatacache.tmp"
        cp -f "$metadatacache.tmp" "$metadatacache"
        awk 'BEGIN {n[""] = ""} $1~/FILE:/ {f=$2; if (FNR!=NR) { na=n[f];pa=p[f]; while (pa != "") {na=n[pa]"/"na; pa=p[pa]}; print f" /"na }; next}   FNR!=NR {next} i=index($0, "parent: ") {p[f]=substr($0, i+length("parent: ")); next} i=index($0, "visibleName: ") {n[f]=substr($0, i+length("visibleName: ")); next}' "$metadatacache" "$metadatacache" > "$metadatacache.u2n"
        awk '{for(i=2;i<=NF;i++) {printf("%s ", $i)} ; print("---///--- " $1) }' "$metadatacache.u2n" | sort > "$metadatacache.n2u"
    fi
}
function print_autocomplete() {
    cat <<EOF
# to be eval'd (or sourced)
geta() {
  "$1" "\$@" D0=geta
}
_geta() {
  local cur=\${COMP_WORDS[COMP_CWORD]}
  local patterns
  mapfile -t patterns < <( (test -f "$2" && sed -e  's@ ---///--- .*\$@@g' "$2") ; echo update-metadata )
  mapfile -t COMPREPLY < <( compgen -W "\$( printf '%q ' "\${patterns[@]}" )" -- "\$cur" | sed 's@ @\\\\ @g' )
}
complete -F _geta geta
EOF
}


# Check arguments

if [ "$#" -lt 1 ]; then
  die_with_usage
fi

# Do our work in a temporary directory
workdir=$(mktemp -d)
remotepath="$1"
name=$(basename "$remotepath")
metadatacache="$W/metadata.cache"
cloud=false
shift

# Lazy generic parameter reading
for i in "$@" ; do
    if echo "$i" | grep -q '=' ; then
        eval "$i"
    fi
done

if [ "$remotepath" = "D0=geta" ] ; then
    D0=geta
    die_with_usage
fi

if [ "$remotepath" = "update-metadata" ] ; then
    update_metadata_cache 1
    exit 0
fi
if [ "$remotepath" = "def-geta" ] ; then
    print_autocomplete "$(readlink -f "${BASH_SOURCE[0]}")" "$metadatacache.n2u"
    exit 0
fi

echo "$workdir"
pushd "$workdir" > /dev/null

# Download the given document using the ReMarkable Tablet or Cloud API
xd() { echo '[[:xdigit:]]\{'$1'\}' ; }
pat=$(xd 8)-$(xd 4)-$(xd 4)-$(xd 4)-$(xd 12)

if echo "$remotepath" | grep -q $pat ; then
    UUID=$(echo "$remotepath" | sed 's@.*\('$pat'\).*@\1@g')
    name="$UUID"
    echo "Getting from the tablet (based on UUID=$UUID), using ssh:"
    scp -q -r remarkable:.local/share/remarkable/xochitl/"$UUID"'*' .
    LOG ls
    if [ \! -f "$UUID.pdf" ] ; then
        NOPDF=true
        echo "Not using pdf (none found)"
    fi
elif [ "$cloud" '!=' "true" ] ; then
    if echo "$remotepath" | grep -q '^[^/]' ; then
        remotepath="/$remotepath"
    fi
    echo "Getting from the tablet (based on path=$remotepath), using ssh:"
    update_metadata_cache
    echo "Looking for UUID in the local metadata cache"
    if ! grep -q "^$remotepath ---///---" "$metadatacache.n2u" ; then
        echo "Name not found... exiting"
        echo ""
        echo "NB: if you renamed or created files on the tablet (the metadata cache is outdated)"
        echo "    then you might want to update the metadata with:"
        echo "$D0 update-metadata"
        exit 1
    fi
    UUID=$(grep "^$remotepath ---///---" "$metadatacache.n2u" | sed 's@.* ---///--- @@g')
    echo "Now retrieving UUID=$UUID, using ssh:"
    scp -q -r remarkable:.local/share/remarkable/xochitl/"$UUID"'*' .
    LOG ls
    if [ \! -f "$UUID.pdf" ] ; then
        NOPDF=true
        echo "Not using pdf (none found)"
    fi
else
    echo "Getting from the cloud, using rmapi"
    LOG $RMAPI get "$remotepath"
    unzip "$name.zip" >/dev/null

    UUID=$(basename "$(ls ./*-*-*.pdf)" .pdf)

    if [ "$UUID" = "" ] ; then
        NOPDF=true
        UUID=$(basename "$(ls ./*-*-*.pagedata)" .pagedata)
        echo "Not using pdf then"
    fi
fi

if LOG ls "./$UUID/"*.rm ; then
    echo "Found annotations"
else
    echo "PDF is not annotated. Exiting."
    #rm -r "$WORK_DIR"
    exit 0
fi


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

    pname=$(cat $UUID.content | awk -v P=$i '/"pages"/ {go=1; p=0; next} go && p==P {print; exit} go {p=p+1}' | sed -e 's@^[^"]*"@@g' -e 's@"[^$]*$@@g')
    if [ ! -f "./$UUID/$pname.rm" ] ; then
        pname=$i
    fi
    
  if LOG ls -l1 "./$UUID/$pname.rm" ; then
      $RM2SVG -c -i ./$UUID/$pname.rm -o $i.svg
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
