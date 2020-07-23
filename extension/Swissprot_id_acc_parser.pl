#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use EMBL_parser;
use Data::Dumper;

my $usage = "usage: $0 swissprot.dat out_file\n\n";

my $swiss_dat_file = $ARGV[0] or die $usage;
my $out_file = $ARGV[1] or die $usage;


main: {

    open (my $ofh, ">$out_file") or die "Error, cannot write to $out_file";
            
    my $embl_parser = new EMBL_parser($swiss_dat_file);


    ## types currently supporting: A
    
    my $record_counter = 0;
    
    while (my $record = $embl_parser->next()) {
        
        $record_counter++;
        print STDERR "\r[$record_counter]    " if $record_counter % 1000 == 0;
        
        my $ID = &get_ID($record);
        
        my @accessions = &get_accessions($record);
        
        foreach  my $acc (@accessions) {
            print $ofh join("\t", $ID, $acc, 'A') . "\n";
        }
        
    }
        
    close $ofh;
    
    exit(0);
    
}


####
sub get_ID {
    my ($record) = @_;

    my $ID_info = $record->{sections}->{ID};
    my @pts = split(/\s+/, $ID_info);

    my $ID = shift @pts;

    return($ID);
}


####
sub get_accessions {
    my ($record) = @_;

    my $acc_text = $record->{sections}->{AC};
    chomp $acc_text;

    my @pts = split(/\s+/, $acc_text);
    
    my @accs;
    foreach my $pt (@pts) {
        $pt =~ s/\;//;
        push (@accs, $pt);
    }
    
    return(@accs);
}
