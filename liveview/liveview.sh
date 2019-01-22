#!/bin/bash

W=$(dirname $(readlink -f $0))
browser=firefox

function getRemarkablePathOfLastEditedPage() {
    ssh remarkable ls -1tr .local/share/remarkable/xochitl/*/*.rm | tail -1
}


function liveview() {
    # TODO: find a way to not copy systematically
    #       - try to run and if fails scp
    #       - in the script, check its own size and
    scp $W/on-remarkable-watch.sh remarkable:

    # TODO allow parameters/ENV to override this, ideally based on document name + page number
    # or use a fixed one like below
    p=$(getRemarkablePathOfLastEditedPage)
    #p=".local/share/remarkable/xochitl/ab5ab6b4-f20a-46cd-8a5a-5a375e935c19/4.rm"

    # TODO Python live better, incremental
    o=TOTO

    (cd "$W" && $browser "view.html#$o.svg" &)

    ssh -C remarkable bash ./on-remarkable-watch.sh "$p" \
    | python3 to-view.py
}

liveview "$@"
