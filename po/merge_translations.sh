#!/bin/sh
cd po

echo "Merging applications-menu"
# first merge from upstream applications-menu
for i in *.po ; do
    if test -f ../budgie-applications-menu/applications-menu/po/$i; then
        echo "merging $i"
        msgcat -o $i $i ../budgie-applications-menu/applications-menu/po/$i  
        msgmerge -U $i budgie-extras.pot
    fi
done

echo "Now merging budgie-desktop"
# now merge from upstream budgie-desktop
git clone https://github.com/getsolus/budgie-translations
for i in *.po ; do
    if test -f budgie-translations/$i; then
        echo "merging $i"
        msgcat -o $i $i budgie-translations/$i
        msgmerge -U $i budgie-extras.pot
    fi
done
# cleanup
rm *~
rm -rf budgie-translations