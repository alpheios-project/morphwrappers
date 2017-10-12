#!/usr/bin/perl

use strict;

use Encode;

use lib qw(.);

use Alpheios::Aramorph3;
use Alpheios::MockRequest;

unless ($ARGV[0])
{
    print "Usage: $0 <comma separated list of words>\n";
    exit 0;
}

Alpheios::Aramorph3::set_basedir("Alpheios/bama2/");

Alpheios::Aramorph3::post_config();

my $request = new MockRequest(decode("utf-8",$ARGV[0]));

Alpheios::Aramorph3::handler($request);




