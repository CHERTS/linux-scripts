#!/usr/bin/perl

# Copyright (c) 2010, Jeremy Cole <jeremy@jcole.us>

# This program is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License as published
# by the Free Software Foundation; or the Artistic License.
# 
# See http://dev.perl.org/licenses/ for more information.

#
# This script expects a numa_maps file as input.  It is normally run in
# the following way:
#
#     # perl numa-maps-summary.pl < /proc/pid/numa_maps
#
# Additionally, it can be used (of course) with saved numa_maps, and it
# will also accept numa_maps output with ">" prefixes from an email quote.
# It doesn't care what's in the output, it merely summarizes whatever it
# finds.
#
# The output should look something like the following:
#
#     N0        :      7983584 ( 30.45 GB)
#     N1        :      5440464 ( 20.75 GB)
#     active    :     13406601 ( 51.14 GB)
#     anon      :     13422697 ( 51.20 GB)
#     dirty     :     13407242 ( 51.14 GB)
#     mapmax    :          977 (  0.00 GB)
#     mapped    :         1377 (  0.01 GB)
#     swapcache :      3619780 ( 13.81 GB)
#

use Data::Dumper;

sub parse_numa_maps_line($$)
{
  my ($line, $map) = @_;

  if($line =~ /^[> ]*([0-9a-fA-F]+) (\S+)(.*)/)
  {
    my ($address, $policy, $flags) = ($1, $2, $3);

    $map->{$address}->{'policy'} = $policy;

    $flags =~ s/^\s+//g;
    $flags =~ s/\s+$//g;
    foreach my $flag (split / /, $flags)
    {
      my ($key, $value) = split /=/, $flag;
      $map->{$address}->{'flags'}->{$key} = $value;
    }
  }

}

sub parse_numa_maps()
{
  my ($fd) = @_;
  my $map = {};

  while(my $line = <$fd>)
  {
    &parse_numa_maps_line($line, $map);

  }
  return $map;
}

my $map = &parse_numa_maps(\*STDIN);

my $sums = {};

foreach my $address (keys %{$map})
{
  if(exists($map->{$address}->{'flags'}))
  {
    my $flags = $map->{$address}->{'flags'};
    foreach my $flag (keys %{$flags})
    {
      next if $flag eq 'file';
      $sums->{$flag} += $flags->{$flag} if defined $flags->{$flag};
    }
  }
}

foreach my $key (sort keys %{$sums})
{
  printf "%-10s: %12i (%6.2f GB)\n", $key, $sums->{$key}, $sums->{$key}/262144;
}
