#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Data::Dumper;

my $usage = "usage: $0 uniref[100|90|50].xml.gz outfile\n\n";

my $xml_file = $ARGV[0] or die $usage;
my $outfile = $ARGV[1] or die $usage;


main: {
    
    my $fh;
    my $ofh;

    if ($xml_file =~ /\.gz$/) {
        open ($fh, "gunzip -c $xml_file | ") or die "Error, cannot open file $xml_file";
    }
    else {
        open ($fh, $xml_file) or die "Error, cannot open file $xml_file";
    }
    
    open ($ofh, ">$outfile") or die "Error, cannot write to $outfile";
    print $ofh join("\t", "Accession", "LinkId", "AttributeType") . "\n";
    
    my $id;
    my $descr;
    my $value = qr/value="(.+?)"/;
    
    while (<$fh>) {
        chomp;
        if($id) {
            if(/<representative/) {
                $id = $descr = undef;
            }
            elsif(m/<name>Cluster: (.+)</) {
                $descr = $1;
            }
            elsif(m/<property type="member count" $value/) {
                $descr .= ", n=$1";
                print $ofh join("\t", $id, $descr, 'D') . "\n";
            }
            elsif(m/<property type="common taxon ID" $value/) {
                print $ofh join("\t", $id, $1, 'T') . "\n";
            }
            elsif(m/<property type="GO.+?" $value/) {
                print $ofh join("\t", $id, $1, 'G') . "\n";
            }
        }
        elsif(/<entry id="(.+?)"/) {
            $id = $1;
        }
    }

    close $fh;
    close $ofh;
    
    exit(0);
}
