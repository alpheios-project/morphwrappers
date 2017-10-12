#!/usr/bin/perl
package Alpheios::LatinMorph;
use strict;
use Benchmark;
use Cwd;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
  
use Apache2::Const -compile => qw(OK);


# Package Global Variables
my $version = "1.0-alpheios";
my $suppress = 0;
my $execDir = '/var/www/perl/Alpheios/latin/wordsxml/platform/Linux_x86-gcc4';
my $execFile = 'wordsxml';
my $usage = <<"END_OF_USAGE";
    LatinMorph: Latin morphological analyzer and POS tagger, v. $version

    Usage:   perl $0 [options] <word1> [<word2> ...]

    Options:
      &h, &help             Print usage
      &v, &version          Print version ($version)
END_OF_USAGE

# Registered as PerlPostConfigHandler, this method should only be called
# once per parent HTTPD process. It initializes the dictionary data which is shared by all child 
# HTTPD Processes and threads.
sub post_config {
    return Apache2::Const::OK;
}



sub handler {
    my $t3 = new Benchmark;
    my $r = shift; # The Apache request object
    my $querystring = $r->args() || q{};
    my %params;
    foreach my $arg (split /[&;]/, $querystring) {
        my ($name,$value) = $arg =~ /^(.+)=(.*)$/;
        push @{$params{$name}},$value;
    }
 
    if ($params{'h'} || $params{'help'} || $params{'v'} || $params{'version'})
    {
        $r->content_type("text/plain");
         print $usage;
        return Apache2::Const::OK;
    }
    # untaint input 
    my $words = join ',', map { s/[^\w|\d|\s]//g; $_; }
                          map { s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex($1))/eg;  
                                $_;
                              }
                          @{$params{word}};
    my $cwd = getcwd;
    print STDERR "Current dir=$cwd\n" unless $suppress;
    chdir($execDir) or warn "$!\n";
    print STDERR "Current dir=" . (getcwd) . "\n" unless $suppress;
    my $response = `./$execFile $words`;
    chdir $cwd;
    $r->content_type("text/xml");
    print $response; 

    my $t4 = new Benchmark; 
    print STDERR timestr(timediff($t4, $t3), 'noc'), "\n" unless $suppress;
    return Apache2::Const::OK;
}


1;
