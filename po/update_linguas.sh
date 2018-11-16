#!/bin/sh
tx pull -f -a --minimum-perc=46

cd po
rm LINGUAS

for i in *.po ; do
    echo `echo $i|sed 's/.po$//'` >> LINGUAS
done

sed -i 's/CHARSET/UTF-8/g' *.po
