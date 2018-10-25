#!/bin/bash

function do_gettext()
{
    xgettext --package-name=budgie-extras --package-version=10.4 $* --default-domain=budgie-extras --join-existing --from-code=UTF-8
}

function do_intltool()
{
    intltool-extract --type=$1 $2
}

rm budgie-extras.po -f
touch budgie-extras.po

for file in `find . -name "*.py" -or -name "*.vala"`; do
    if [[ `grep -F "_(\"" $file` ]]; then
        do_gettext $file --add-comments
    fi
done

#for file in `find src -name "*.ui"`; do
#    if [[ `grep -F "translatable=\"yes\"" $file` ]]; then
#        do_intltool gettext/glade $file
#        do_gettext ${file}.h --add-comments --keyword=N_:1
#        rm $file.h
#    fi
#done

for file in `find . -name "*.in"`; do
    if [[ `grep -E "^_*" $file` ]]; then
        do_intltool gettext/keys $file
        do_gettext ${file}.h --add-comments --keyword=N_:1
        rm $file.h
    fi
done

mv budgie-extras.po po/budgie-extras.pot
