#!/usr/bin/env perl

use strict;
use warnings;

use Furl;
use JSON::PP qw(encode_json decode_json);

use constant COMEDIAN => "/Y^_^Y/";

my ($from_server, $to_server) = @ARGV[0, 1];

my $json = JSON::PP->new->ascii;

my $ua = Furl->new;
my $res = $ua->get($from_server . COMEDIAN);

# $from_server
my $registry = decode_json($res->content);
for my $what (values %$registry) {
    $ua->post(
        $to_server . COMEDIAN,
        [],
        $json->encode($what),
    );
}
