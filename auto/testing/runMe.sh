#!/bin/bash

for file in *.gz
do
  if [ ! -e ${file%.gz} ]; then
      gunzip -c $file > ${file%.gz}
  fi
done


makeblastdb -in mini_sprot.pep -dbtype prot

SWISSPROT_SQLITE_DB_URL="https://data.broadinstitute.org/Trinity/Trinotate_v3_RESOURCES/Trinotate_v3.sqlite.gz";

BOILERPLATE="Trinotate.boilerplate.sqlite"

if [ -e $BOILERPLATE ]; then
    echo $BOILERPLATE
    rm $BOILERPLATE
fi

if [ ! -s $BOILERPLATE.gz ]; then
    echo pulling swissprot resource db from ftp site
    wget $SWISSPROT_SQLITE_DB_URL -O $BOILERPLATE.gz
fi

gunzip -c $BOILERPLATE.gz > $BOILERPLATE


sqlite_db="my.sqlite"



../autoTrinotate.pl --Trinotate_sqlite my.sqlite --transcripts Trinity.fasta --gene_to_trans_map Trinity.fasta.gene_to_trans_map --conf conf.txt --CPU 10
