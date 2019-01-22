#!/bin/bash

W=$(dirname $(readlink -f $0))
browser=firefox

#function getRemarkablePathOfLastEditedPage() {
#    ssh remarkable ls -1tr .local/share/remarkable/xochitl/*/*.rm | tail -1
#}

function run_and_copy_on_error() {
  local sha=$(cat $W/on-remarkable-watch.sh | sha1sum)
  {
    ssh -C remarkable bash ./on-remarkable-watch.sh "$1" "$sha" \
    || \
    {
      echo "Copying on-remarkable-watch.sh" 1>&2
      scp $W/on-remarkable-watch.sh remarkable:
      ssh -C remarkable bash ./on-remarkable-watch.sh "$1" "$sha"
    }
  }
}

function liveview() {
    # TODO: find a way to not copy systematically
    #       - try to run and if fails scp
    #       - in the script, check its own size and
    #scp $W/on-remarkable-watch.sh remarkable:

    # TODO allow parameters/ENV to override this, ideally based on document name + page number
    # or use a fixed one like below
    #p=$(getRemarkablePathOfLastEditedPage)
    #p=".local/share/remarkable/xochitl/ab5ab6b4-f20a-46cd-8a5a-5a375e935c19/4.rm"
    p="//" # to mean, the latest page of the latest document

    # TODO Python live better, incremental
    o=TOTO


    (cd "$W" && $browser "view.html#$o.svg" &)

    run_and_copy_on_error "$p" | python3 $W/to-view.py "$W/$o.rm" "$W/$o.svg"
}

liveview "$@"
