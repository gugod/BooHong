#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;
use Test2::V0;
use JSON::PP qw<encode_json>;
use HTTP::Tiny;

# $ENV{TEST_SERVER} = 
my $TEST_SERVER = "http://localhost:5000";

subtest "A simple mocking request." => sub {
    my $URI_PATH = "/whatever/" . int(rand(64));

    my $response;
    note "In the beginning there is nothing";

    $response = HTTP::Tiny->new->get($TEST_SERVER . $URI_PATH);
    is $response->{status}, "501";

    note "After mutating";
    my $body_randomness = rand();
    my $body = qq<{"message":"hello","rand":"${body_randomness}"}>;
    $response = HTTP::Tiny->new->post(
        $TEST_SERVER . "/Y^_^Y/",
        {
            content => encode_json({
                request => {
                    method => "GET",
                    path => $URI_PATH,
                },
                response => {
                    status => 200,
                    headers => [
                        "Set-Cookies" => "foo=bar",
                    ],
                    body => $body
                }
            })
        }
    );

    note "It responds with the response we ask it to";

    $response = HTTP::Tiny->new->get($TEST_SERVER . $URI_PATH);
    is $response->{status}, "200";
    is $response->{content}, $body;
};

done_testing;
