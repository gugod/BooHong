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

    $response = HTTP::Tiny->new->get($TEST_SERVER . $URI_PATH);
    is $response->{status}, "501", "In the beginning it does not know how to bôo‑hóng.";

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
    is $response->{status}, 200, "Mutation success.";

    $response = HTTP::Tiny->new->get($TEST_SERVER . $URI_PATH);
    is $response->{status}, "200", "The response status looks about right";
    is $response->{content}, $body, "The response body looks about right";

    $response = HTTP::Tiny->new->delete(
        $TEST_SERVER . "/Y^_^Y/",
        {
            content => encode_json({
                request => {
                    method => "GET",
                    path => $URI_PATH,
                },
            }),
        }
    );
    is $response->{status}, 200, "Now, un-learn how to bôo‑hóng";

    $response = HTTP::Tiny->new->get($TEST_SERVER . $URI_PATH);
    is $response->{status}, "501", "Indeed, it does not know how do $URI_PATH anymore";
};

done_testing;
