#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Plack::Request;
use Plack::Response;
use JSON::PP qw<encode_json decode_json>;

# pick a sensible URI path for myself and it must not be used by my bosses.
use constant COMEDIAN => "/Y^_^Y/";

sub process {
    my ($self, $req) = @_;

    my $path = $req->path_info;
    my $method = $req->method;

    my $sig = request_digest({
        method => $req->method,
        path => $req->request_uri,
        headers => $req->headers->psgi_flatten,
        body => $req->content,
    });

    my $what = $self->{registry}{$sig};
    return undef unless $what;

    return $req->new_response(
        $what->{response}{status},
        $what->{response}{headers},
        $what->{response}{body},
    );
}

use constant IS_CONTENT_UNRELATED_HEADER => { map { (lc($_), 1) } qw(Accept-Encoding Server Date Connection Host Content-Length User-Agent) };

sub request_digest {
    my ($o) = @_;
    state $json = JSON::PP->new->canonical->ascii;
    my @headers;

    for (my $i = 0; $i < @{$o->{headers}}; $i += 2) {
        my $k = $o->{headers}[$i];
        next if IS_CONTENT_UNRELATED_HEADER->{ lc($k) };
        push @headers, $k, $o->{headers}[$i+1];
    }

    my $txt = $json->encode({
        headers => \@headers,
        method => $o->{method},
        path => $o->{path},
        # body => $o->{body},
    });
    return md5_base64($txt);
}

sub register {
    my ($self, $what) = @_;
    my $sig = request_digest($what->{request});
    $self->{registry}{$sig} = $what;
}

sub unregister {
    my ($self, $what) = @_;
    my $sig = request_digest($what->{request});
    delete $self->{registry}{$sig};
}

sub list_registry {
    my ($self, $req) = @_;
    my $json = JSON::PP->new->ascii;
    return $req->new_response(
        200,
        [],
        $json->encode($self->{registry}),
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
