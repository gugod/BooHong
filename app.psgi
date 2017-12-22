#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use Plack::Request;
use Plack::Response;
use JSON::PP qw<encode_json decode_json>;

use constant COMEDIAN => "/Y^_^Y/";

sub process {
    my ($self, $req) = @_;

    my $path = $req->path_info;
    my $what = $self->{registry}{by_path}{$path};
    return undef unless $what;

    return $req->new_response(
        $what->{response}{status},
        $what->{response}{headers},
        $what->{response}{body},
    );
}

sub register {
    my ($self, $content) = @_;
    my $what = decode_json($content);
    $self->{registry}{by_path}{$what->{request}{path}} = $what;
}


my $app = sub {
    state $self = bless { registry => {} } => __PACKAGE__;

    my $env = shift;
    my $req = Plack::Request->new($env);
    my $res;

    if ($req->path_info eq COMEDIAN) {
        if ($req->method eq 'POST') {
            $self->register($req->content);
        }
    } else {
        $res = $self->process($req);
    }

    $res //= $req->new_response(501);
    $res->finalize;
};


$app;

=head1 HOW

=over 4

=item POST /Y^_^Y/

Example of request body:

    {
        "request": {
            "method": "GET",
            "path": "/dir1/dir2/dir3"
        },
        "response": {
            "status": 200,
            "headers": [
                "Set-Cookies": "foo=bar"
            ],
            "body": "{\"message\":\"nihao\"}"
        }
    }

Response:

This request mutate the request "GET /dir1/dir2/dir3" to respond
with the "response" defined in the request. (Confused ? :)

Effect: After this request, this request will start to produce response:

    GET /dir1/dir2/dir3

    #=>
    HTTP/1.1 200
    Set-Cookies: foo=bar
    
    {"message":"nihao"}

=back

=cut
