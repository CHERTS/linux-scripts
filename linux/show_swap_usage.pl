#!/usr/bin/perl -w

use strict;
use Getopt::Std;
my ($tot,$mtot)=(0,0);
my %procs;

my %opts;
getopt('', \%opts);

sub sortres {
    return $a <=> $b                                          if $opts{'p'};
    return $procs{$a}->{'cmd'} cmp $procs{$b}->{'cmd'}        if $opts{'c'};
    return $procs{$a}->{'mswap'} <=> $procs{$b}->{'mswap'}    if $opts{'m'};
    return $procs{$a}->{'swap'} <=> $procs{$b}->{'swap'};
};

opendir my $dh,"/proc";

for my $pid (grep {/^\d+$/} readdir $dh) {
    if (open my $fh,"</proc/$pid/status") {
        my ($sum,$nam)=(0,"");
        while (<$fh>) {
            $sum+=$1 if /^VmSwap:\s+(\d+)\s/;
            $nam=$1 if /^Name:\s+(\S+)/;
        }
        if ($sum) {
            $tot+=$sum;
            $procs{$pid}->{'swap'}=$sum;
            $procs{$pid}->{'cmd'}=$nam;
            close $fh;
            if (open my $fh,"</proc/$pid/smaps") {
                $sum=0;
                while (<$fh>) {
                    $sum+=$1 if /^Swap:\s+(\d+)\s/;
                };
            };
            $mtot+=$sum;
            $procs{$pid}->{'mswap'}=$sum;
        } else { close $fh; };
    };
};
map {
    printf "PID: %9d  swapped: %11d (%11d) KB (%s)\n",
        $_, $procs{$_}->{'swap'}, $procs{$_}->{'mswap'}, $procs{$_}->{'cmd'};
} sort sortres keys %procs;
printf "Total swapped memory: %14u (%11u) KB\n", $tot,$mtot;
