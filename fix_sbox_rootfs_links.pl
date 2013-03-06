#!/usr/bin/perl -w

use strict;
use warnings;
use autodie;
use File::Basename;
use File::Spec;

my $CURDIRVAL=`pwd`;
chomp($CURDIRVAL);

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
            if ($target=~/^\/lib\//) {
                my ($lnvolume, $lndirectories, $lnfile) = File::Spec->splitpath($target);
                unlink $file;
                symlink("../../lib/$lnfile", "$file");
                print "$file -> $target : target-file: $lnfile broken\n";
            }
            if ($target=~/^\/opt\//) {
                my ($lnvolume, $lndirectories, $lnfile) = File::Spec->splitpath($target);
                unlink $file;
                symlink("../../opt/lib/$lnfile", "$file");
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
system("chmod a+rw ../../lib/libgcc_s.so");
system("echo 'GROUP ( libgcc_s.so.1 libgcc.a )' > ../../lib/libgcc_s.so");

system("echo 'OUTPUT_FORMAT(elf32-littlearm)' > libc.so");
system("echo 'GROUP ( ../../lib/libc.so.6 libc_nonshared.a  AS_NEEDED ( ../../lib/ld-linux.so.3 ) )' >> libc.so");

system("echo 'OUTPUT_FORMAT(elf32-littlearm)' > libpthread.so");
system("echo 'GROUP ( ../../lib/libpthread.so.0 libpthread_nonshared.a )' >> libpthread.so");

system("rm -f ./libstdc++.so");
symlink("libstdc++.so.6", "libstdc++.so");

chdir("$CURDIRVAL/../bin");
opendir my $dirhb, '.';
while (my $file = readdir $dirhb) {
    if ( -l $file ) {  
        my $target = readlink $file;
        if ( ! -e $target && ! -l $target ) {
            if ($target=~/\/usr\/bin\//) {
                my ($lnvolume, $lndirectories, $lnfile) = File::Spec->splitpath($target);
                unlink $file;
                symlink("$CURDIRVAL/../bin/$lnfile", "$file");
                print "$file -> $target : target-file: $lnfile broken\n";
            }
        }
    }
}
