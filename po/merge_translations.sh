#!/bin/sh
cd po

echo "Merging applications-menu"
# first merge from upstream applications-menu
for i in *.po ; do
    if test -f ../budgie-applications-menu/applications-menu/po/$i; then
        echo "merging $i"
        msgcat -o $i $i ../budgie-applications-menu/applications-menu/po/$i  
        msgmerge -U $i budgie-extras.pot
    else
        echo "not found $i lets check the generic language is available"
        
        PART=$(echo $i | cut -d'_' -f 1)
        PART="${PART}.po"
        if test -f ../budgie-applications-menu/applications-menu/po/$PART; then
            echo "merging $PART"
            msgcat --use-first -o $i $i ../budgie-applications-menu/applications-menu/po/$PART  
            msgmerge -U $i budgie-extras.pot
        fi
    fi
done

echo "Merging network applet"
for i in *.po ; do
    if test -f ../budgie-network-manager/budgie-network-applet/po/$i; then
        echo "merging $i"
        msgcat -o $i $i ../budgie-network-manager/budgie-network-applet/po/$i  
        msgmerge -U $i budgie-extras.pot
    else
        echo "not found $i lets check the generic language is available"
        
        PART=$(echo $i | cut -d'_' -f 1)
        PART="${PART}.po"
        if test -f ../budgie-network-manager/budgie-network-applet/po/$PART; then
            echo "merging $PART"
            msgcat --use-first -o $i $i ../budgie-network-manager/budgie-network-applet/po/$PART  
            msgmerge -U $i budgie-extras.pot
        fi
    fi
done

echo "Now merging budgie-desktop"
# now merge from upstream budgie-desktop
git clone https://github.com/getsolus/budgie-translations
for i in *.po ; do
    if test -f budgie-translations/$i; then
        echo "merging $i"
        msgcat --use-first -o $i $i budgie-translations/$i
        msgmerge -U $i budgie-extras.pot
    else
        echo "not found $i lets check the generic language is available"
        
        PART=$(echo $i | cut -d'_' -f 1)
        PART="${PART}.po"
        if test -f budgie-translations/$PART; then
            echo "merging $PART"
            msgcat -o $i $i budgie-translations/$PART  
            msgmerge -U $i budgie-extras.pot
        fi
    fi
done
# cleanup
rm *~
rm -rf budgie-translations