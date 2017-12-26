#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use Plack::Request;
use Plack::Response;
use JSON::PP qw<encode_json decode_json>;

# pick a sensible URI path for myself and it must not be used by my bosses.
use constant COMEDIAN => "/Y^_^Y/";

sub process {
    my ($self, $req) = @_;

    my $path = $req->path_info;
    my $method = $req->method;

    my $what = $self->{registry}{$method}{$path};
    return undef unless $what;

    return $req->new_response(
        $what->{response}{status},
        $what->{response}{headers},
        $what->{response}{body},
    );
}

sub register {
    my ($self, $what) = @_;
    $self->{registry}{$what->{request}{method}}{$what->{request}{path}} = $what;
}

sub unregister {
    my ($self, $what) = @_;
    delete $self->{registry}{$what->{request}{method}}{$what->{request}{path}};
}

sub list_registry {
    my ($self, $req) = @_;
    return $req->new_response(
        200,
        {},
        encode_json($self->{registry}),
    );
}

my $app = sub {
    # So... since the registry lives in this object, this app can only run as a single process. No forking. :)
    state $self = bless { registry => {} } => __PACKAGE__;

    my $env = shift;
    my $req = Plack::Request->new($env);
    my $res;

    if ($req->path_info eq COMEDIAN) {
        if ($req->method eq 'GET') {
            $res = $self->list_registry($req);
        } else {
            my $what = decode_json($req->content);
            if ($req->method eq 'POST') {
                $self->register($what);
            } elsif ($req->method eq 'DELETE') {
                $self->unregister($what);
            }
        }
        $res //= $req->new_response(200, [], '{}');
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
                "Set-Cookies", "foo=bar"
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

=item DELETE /Y^_^Y/

Delete one mock described in the body.

Example of request body:

    {
        "request": {
            "method": "GET",
            "path": "/dir1/dir2/dir3"
        }
    }

This request is idempotent and always return successfully even if the
described is never registered.

=back

=cut
