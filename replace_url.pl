#!/usr/bin/perl

use 5.16.3;
use warnings;
use IO::File;

main(@ARGV);

sub main {
  # make sure we have a filename from the command line, and the production and test domains
  my ($backupFile, $prodDomainName, $testDomainName) = @ARGV;
  die "Missing filename on the command line." unless $backupFile;
  die "Missing production domain name on the command line." unless $prodDomainName;
  die "Missing test domain name on the command line." unless $testDomainName;

  # open the file
  my $fh = IO::File->new($backupFile, "r");
  die "Cannot open $backupFile ($!)\n" unless $fh;

  # read the file line by line
  while (my $line = $fh->getline) {
    replaceURL($line, $prodDomainName, $testDomainName);
  }

  $fh->close;
}

sub replaceURL {
  my $line = $_[0];
  my $prodDomainName = $_[1];
  my $testDomainName = $_[2];
  my $prodWwwDomainName = 'www.' . $prodDomainName;
  my $lengthDiff = length($testDomainName) - length($prodDomainName);
  my $lengthWwwDiff = length($testDomainName) - length($prodWwwDomainName);

  # first, replace example.org and www.example.org within serialized objects
  #   e.g. s30:\"https://crm.example.org/whatever
  # we need to replace the url and increase the number after the s
  #   ==>  s34:\"https://testcrm.example.org/whatever  
  $line =~ s/s:(\d+):(\\"http[s]?:\/\/)$prodDomainName/'s:' . ($1+$lengthDiff) . ':' . $2 . $testDomainName/ge;
  $line =~ s/s:(\d+):(\\"http[s]?:\/\/)$prodWwwDomainName/'s:' . ($1+$lengthWwwDiff) . ':' . $2 . $testDomainName/ge;

  # next, we replace the other occurrences
  $line =~ s/\/\/$prodDomainName/\/\/$testDomainName/g;
  $line =~ s/\/\/$prodWwwDomainName/\/\/$testDomainName/g;

  print $line;
}


