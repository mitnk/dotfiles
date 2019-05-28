#!/usr/local/bin/cicada
function show-usage {
    echo -t " [num]  show 10 (or num) last updated notes"
    echo -tr "[num]  show 10 (or num) oldest, not touched notes"
    echo -l "xxx"
    echo "     search xxx and only show note names"
    echo "<args>"
    echo "     pass <args> to rg on all notes"
}

if [ -z "$1" ]
    show-usage
    exit 0
fi
if [ "$1" = "-h" -o "$1" = "--help" ]
    show-usage
    exit 0
fi

limit=10
if [ $1 = "-t" ]
    if [ ! -z $2 ]
        limit="$2"
    fi
    find /Users/hugo/Dropbox/enotes -type f -name '*.md' | xargs ls -t | head -n $limit | xargs exa -lh -s time
    exit 0
fi

if [ $1 = "-tr" -o $1 = "-rt" ]
    if [ ! -z $2 ]
        limit="$2"
    fi
    find /Users/hugo/Dropbox/enotes -type f -name '*.md' | xargs ls -tc | tail -n $limit | xargs exa -lh -s time
    exit 0
fi

if [ $1 = "-l" ]
    rg $@ ~/Dropbox/enotes | xargs exa -lh -s time
    exit 0
fi

echo rg $@ ~/Dropbox/enotes
echo
rg $@ ~/Dropbox/enotes
