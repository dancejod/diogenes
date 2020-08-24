#!/usr/bin/env -S perl -w
use strict;

use FindBin qw($Bin);
use File::Spec::Functions qw(:ALL);

my $txt_file = catdir($Bin, '..', 'tlg-chronology.txt');
my $pl_file  = catdir($Bin, '..', 'server', 'tlg-chronology.pl');

open my $txt_fh, "<$txt_file" or die "Could not open $txt_file: $!";
open my $pl_fh,  ">$pl_file"  or die "Could not open $pl_file for writing: $!";

my $array = '@Diogenes::Base::tlg_chron_order = (
';
my $hash  = '%Diogenes::Base::tlg_chron_info = (
';

while (<$txt_fh>) {
    if (m/^(\d\d\d\d)\s+(.*?)$/) {
        my $num = $1;
        my $date = $2;
        $date =~ s/\s+$//;
        $array .= qq{"$num",\n};
        $hash  .= qq{"$num" => "$date",\n};
    }
    else {
        die "Badly formed line: $_";
    }
}

$array =~ s/,\n$//s;
$hash =~ s/,\n$//s;

$array .= ");\n\n";
$hash  .= ");\n";

#print $array;
# print $hash;

print $pl_fh "# This file is auto-generated by make_tlg_chronology.pl.  
# Do not edit it.\n\n";

print $pl_fh $array;
print $pl_fh $hash;

print "Done.\n";

