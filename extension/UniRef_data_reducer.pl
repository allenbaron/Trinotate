#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Sqlite_connect;
use List::Util 'first';

my $usage = "usage: $0 Trinotate.sqlite uniref_UPI.tsv uniref_UPI_reduced.tsv\n\n";

my $sqlite_db = $ARGV[0] or die $usage;
my $tsv_file = $ARGV[1] or die $usage;
my $outfile = $ARGV[2] or die $usage;


main: {
    
    my $fh;

    if ($tsv_file =~ /\.gz$/) {
        open ($fh, "gunzip -c $tsv_file | ") or die "Error, cannot open file $tsv_file";
    }
    else {
        open ($fh, $tsv_file) or die "Error, cannot open file $tsv_file";
    }
    
    open (my $ofh, ">$outfile") or die "Error, cannot write to $outfile";
    
    my $dbproc = &connect_to_db($sqlite_db);
    my @results = &get_uniref_accessions($dbproc);

    $dbproc->disconnect();

    my %include = map { $_ => 1 } @results;
        
    while (<$fh>) {
        my @F = split("\t");
        if(exists($include{$F[0]})) {
             print $ofh $_; 
        }
    }

    close $fh;
    close $ofh;
    
    exit(0);
}


sub get_uniref_accessions {
    my ($dbproc) = @_;

    my $query = "SELECT DatabaseSource from BlastDbase";
    my @dbases = &do_sql2array($dbproc, $query);
    my $db_name = first { /uniref/i } @dbases;
    
    $query = "SELECT FullAccession FROM BlastDbase"
            . " WHERE DatabaseSource = ?;";
    my @accessions = &do_sql2array($dbproc, $query, $db_name);
    my %seen =();
    my @uniq_accessions = grep { ! $seen{$_}++ } @accessions;
    
    return(@uniq_accessions);
}
