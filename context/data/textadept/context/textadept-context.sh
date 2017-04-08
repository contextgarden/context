#!/bin/sh

# copied from setuptex

if [ z"$BASH_SOURCE" != z ]; then
    textadept -u $(cd -P -- "$(dirname -- "$BASH_SOURCE")" && pwd -P) "$@" &
elif [ z"$KSH_VERSION" != z ]; then
    textadept -u $(cd -P -- "$(dirname -- "${.sh.file}")" && pwd -P) "$@" &
else
    textadept -u $(cd -P -- "$(dirname -- "$0")" && pwd -P) "$@" &
fi

