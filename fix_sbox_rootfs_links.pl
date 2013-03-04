#!/usr/bin/perl -w

use strict;
use warnings;
use autodie;
use File::Basename;
use File::Spec;

my $CURDIRVAL=`pwd`;

if ($CURDIRVAL=~/scratchbox.*users.*target.*\/usr\/lib/) {
  print "Applying sbox rootfs script on $CURDIRVAL\n";
} else {
  print "Make sure that script is running in scratchbox rootfs /usr/lib directory\n  Ex: /scratchbox/users/whoami/targets/HARMATTAN_ARMEL/usr/lib\n";
  exit(0);
}

opendir my $dirh, '.';
while (my $file = readdir $dirh) {
    if ( -l $file ) {  
        my $target = readlink $file;
        if ( ! -e $target && ! -l $target ) {
            if ($target=~/\/lib\//) {
                my ($lnvolume, $lndirectories, $lnfile) = File::Spec->splitpath($target);
                unlink $file;
                symlink("../../lib/$lnfile", "$file");
                print "$file -> $target : target-file: $lnfile broken\n";
            }
        }
    }
}

system("mkdir -p backup.nss");
my $nssfiles="./libnspr4.a
./libnspr4.so
./libnss3.so
./libnssckbi.so
./libnssdbm3.chk
./libnssdbm3.so
./libnssutil3.so
./libsmime3.so
./libssl3.so
";

while ($nssfiles=~/^(.*)$/gm) {
    my $nssfile=$1;
    print "Moving $nssfile to backup.nss\n";
    system("mv $nssfile ./backup.nss/");
}

system("rm -f ./libstdc++.so");
symlink("./libstdc++.so.6.0.12", "./libstdc++.so");
