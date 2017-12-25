#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use Data::Dumper;

use Furl;
use Furl::Request;

use Plack::Request;
use Plack::Response;
use JSON::PP qw<encode_json decode_json>;

use Plack::Util;
use Plack::Builder;
use Plack::App::Proxy;
use Ref::Util qw(is_arrayref is_coderef);

use constant BOOHONG_SERVER => $ENV{BOOHONG_SERVER} // "http://localhost:5000";
use constant BOOHONG_TARGET => $ENV{BOOHONG_TARGET} // die("Require BOOHONG_TARGET");

sub boohong_it {
    my ($env, $status_headers_body) = @_;

    my $req = Plack::Request->new($env);
    my $res = Plack::Response->new($status_headers_body);

    my $body = $status_headers_body->[2];
    if (is_arrayref($body)) {
        $body = join "", @$body;
    } elsif (is_coderef($body)) {
        $body = $body->();
    }

    my $what = {
        request => {
            method => $req->method,
            path => $req->request_uri,
            # headers => ...
            # body => ...
        },
        response => {
            status => $status_headers_body->[0],
            headers => $status_headers_body->[1],
            body => $body,
        },
    };

    my $furl_request = Furl::Request->new(
        $req->method,
        BOOHONG_SERVER . $req->request_uri,
        $req->headers->psgi_flatten,
        $req->body,
    );
    my $furl = Furl->new;
    my $boohong_res = $furl->request($furl_request);

    return;
}

builder {
    enable sub {
        my $proxy_app = shift;
        sub {
            my $env = shift;
            $env->{'plack.proxy.url'} = BOOHONG_TARGET . $env->{REQUEST_URI};
            my $proxy_res = $proxy_app->($env);
            return Plack::Util::response_cb(
                $proxy_res,
                sub {
                    my $status_headers_body = $_[0];
                    boohong_it($env, $status_headers_body);
                    return;
                }
            );
        }
    };
    Plack::App::Proxy->new()->to_app;
};
