#!/bin/bash

export PATH=$HOME/bin:$HOME/.cabal/bin:$PATH

installed() {
    ghc-pkg latest $1 > /dev/null 2>&1
}

install() {
    echo cabal install "$@"
    cabal install --haddock-hoogle --haddock-html       \
        --haddock-executables --haddock-internal        \
        --haddock-hyperlink-source "$@"
}

install_prereqs() {
    if ! installed Cabal; then
        install Cabal cabal-install
    fi

    if ! test -x "$(which alex)"; then
        install -j --disable-executable-dynamic alex
    fi
    if ! test -x "$(which happy)"; then
        install -j happy
    fi
    if ! test -x "$(which HsColour)"; then
        install -j hscolour
    fi
    if ! test -x "$(which c2hs)"; then
        install -j c2hs
    fi

    if ! installed text-icu; then
        DYLD_LIBRARY_PATH=/usr/local/opt/icu4c/lib                      \
            install -j1 text-icu                                        \
                --extra-include-dirs=/usr/local/opt/icu4c/include       \
                --extra-lib-dirs=/usr/local/opt/icu4c/lib
    fi
    if ! installed libxml-sax; then
        PKG_CONFIG_PATH=/usr/local/opt/libxml2/lib/pkgconfig            \
            install -j1 libxml-sax                                      \
                --extra-include-dirs=/usr/local/opt/libxml2/include     \
                --extra-lib-dirs=/usr/local/opt/libxml2/lib
    fi
    if ! installed readline; then
        DYLD_LIBRARY_PATH=/usr/local/opt/readline/lib                                           \
            install -j1 readline                                                                \
                --extra-include-dirs=/usr/local/opt/readline/include                            \
                --extra-lib-dirs=/usr/local/opt/readline/lib                                    \
                --configure-option=--with-readline-includes=/usr/local/opt/readline/include     \
                --configure-option=--with-readline-libraries=/usr/local/opt/readline/lib
    fi
    if ! installed libffi; then
        DYLD_LIBRARY_PATH=/usr/local/opt/libffi/lib                     \
        PKG_CONFIG_PATH=/usr/local/opt/libffi/lib/pkgconfig             \
            install -j1 libffi                                          \
                --extra-include-dirs=/usr/local/opt/libffi/include      \
                --extra-lib-dirs=/usr/local/opt/libffi/lib
    fi
}

install_postreqs() {
    if ! test -x "$(which gtk2hsTypeGen)"; then
        install -f have-quartz-gtk -j gtk2hs-buildtools
    fi
    if ! installed glib; then
        install -f have-quartz-gtk -j glib gtk cairo
    fi
    if ! test -x "$(which threadscope)"; then
        install -f have-quartz-gtk -j threadscope splot #timeplot
    fi
}

do_cabal() {
    $1 install -j --only-dependencies --force-reinstalls --dry-run      \
        | perl -i -ne 'print unless / /;'                               \
        | perl -i -ne 'print if /-[0-9]+/;'                             \
        | perl -pe 's/-[0-9].+//;'
}

# if ! installed cabal-meta; then
#     install cabal-meta
# fi

rm -f /tmp/deps

# find ~/Contracts/ ~/Projects/ ~/Mirrors/ -maxdepth 1 -type d \
#     | while read dir ; do
#     if [[ -f $dir/sources.txt ]]; then
#         (cd $dir ; do_cabal cabal-meta >> /tmp/deps 2> /dev/null) || echo skip
#     elif [[ -f "$(echo $dir/*.cabal)" ]]; then
#         (cd $dir; do_cabal cabal >> /tmp/deps 2> /dev/null) || echo skip
#     fi
# done

cat >> /tmp/deps <<EOF
doctest
doctest-prop
hspec
hspec-expectations

simple-reflect
pretty-show

CC-delcont
Boolean
acid-state
adjunctions
attempt
bifunctors
categories
classy-prelude
comonad
comonad-transformers
compdata
composition
cond
conduit
convertible
distributive
directory
either
esqueleto
exceptions
filepath
filesystem-conduit
free
http-conduit
kan-extensions
keys
lens
lifted-async
lifted-base
linear
monad-control
monad-coroutine
monad-logger
monad-loops
monad-par
monad-par-extras
monad-stm
monadloc
monoid-extras
newtype
numbers
operational
persistent
persistent-sqlite
persistent-postgresql
persistent-template
pointed
posix-paths
process
profunctor-extras
profunctors
reducers
reflection
regex-applicative
resource-pool
resourcet
retry
rex
safe
safe-failure
scotty
semigroupoids
semigroups
simple-reflect
snappy
speculation
spoon
stm-chans
stm-conduit
stm-stats
strict
system-fileio
system-filepath
tables
tagged
tagged-transformer
these
timers
void

configurator
cpphs
ekg
hlint
optparse-applicative
orc
shake
shelly
EOF

#    git-annex
#    git-monitor
#    hledger
#    darcs
#    idris
#    agda
#    lambdabot
#    mueval
#    unlambda
#    pointfree

for i in                                        \
    c2hsc                                       \
    cabal-db                                    \
    cabal-dev                                   \
    ghc-core                                    \
    git-all                                     \
    git-monitor                                 \
    hasktags                                    \
    hdevtools                                   \
    hlint                                       \
    hobbes                                      \
    hsenv                                       \
    rehoo                                       \
    sizes                                       \
    stylish-haskell                             \
    una                                         \
    yesod
do
    if [[ ! -x "$(which $i)" ]]; then
        echo $i >> /tmp/deps
    fi
done

# Libraries that are currently broken
for i in cabal-file-th #linear
do
    perl -i -ne "print unless /^$i/;" /tmp/deps
done

# Libraries that are already installed
for i in $(ghc-pkg list | egrep -v '(^/|\()' | sed 's/-[0-9].*//')
do
    perl -i -ne "print unless /^$i/;" /tmp/deps
done

install_prereqs

uniqify /tmp/deps
install "$@" -j $(< /tmp/deps) || (echo "Cabal build plain failed"; exit 1)

#install_postreqs

ghc-pkg check
