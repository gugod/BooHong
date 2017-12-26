#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

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
            headers => $req->headers->psgi_flatten,
            body => $req->content,
        },
        response => {
            status => $status_headers_body->[0],
            headers => $status_headers_body->[1],
            body => $body,
        },
    };

    my $furl_request = Furl::Request->new(
        $req->method,
        BOOHONG_SERVER . "/Y^_^Y/",
        [],
        encode_json($what),
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
            my $content = "";
            return Plack::Util::response_cb(
                $proxy_app->($env),
                sub {
                    my $res = shift;
                    return sub {
                        my ($chunk) = @_;
                        if (defined($chunk)) {
                            $content .= $chunk;
                        } else {
                            $res->[2] = $content;
                            boohong_it($env, $res);
                        }
                    }
                }
            );
        }
    };
    Plack::App::Proxy->new(backend => "LWP")->to_app;
};
