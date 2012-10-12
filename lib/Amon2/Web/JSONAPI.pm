package Amon2::Web::JSONAPI;
use strict;
use warnings;
use utf8;
use 5.010001;
our $VERSION = '0.01';
# undocumented, but it's possible.
our $ALLOW_JSON_HIJACKING = 0;

use Router::Simple ();
use Amon2 ();
use Amon2::Web ();
use Carp ();
use Plack::Util ();

sub import {
    my ($class, $child) = @_;
    my $pkg = caller(0);
    my $router = Router::Simple->new();
    no strict 'refs';
    unless ($pkg->isa('Amon2')) {
        unshift @{"${pkg}::ISA"}, 'Amon2';
    }
    unless ($pkg->isa('Amon2::Web')) {
        unshift @{"${pkg}::ISA"}, 'Amon2::Web';
    }
    unshift @{"${pkg}::ISA"}, 'Amon2::Web::JSONAPI::Impl';
    unless ($pkg->can('render_json')) {
        $pkg->load_plugin(qw/Web::JSON/);
    }
    if ($child) {
        # use Amon2::Web::JSONAPI -DFV;
        # use Amon2::Web::JSONAPI "+My::Own::Validator";
        $child =~ s/^-//;
        $child = Plack::Util::load_class($child, __PACKAGE__);
        unshift @{"${pkg}::ISA"}, $child;
    }
    *{"${pkg}::post"} = sub { # post($path[, $rule], $code);
        my $path = shift @_;
        my $code = pop @_;
        Carp::croak "Code must be code." unless ref $code eq 'CODE';
        my $arg = +{
            code   => $code,
            method => 'POST',
        };
        if (@_) {
            $arg->{rule} = shift @_;
        }
        $router->connect($path, $arg)
    };
    *{"${pkg}::get"} = sub {  # get($path[, $rule], $code);
        my $path = shift @_;
        my $code = pop @_;
        Carp::croak "Code must be code." unless ref $code eq 'CODE';
        my $arg = +{
            code   => $code,
            method => 'GET',
        };
        if (@_) {
            $arg->{rule} = shift @_;
        }
        $router->connect($path, $arg)
    };
    *{"${pkg}::any"} = sub { # any($path, [, $rule], $code);
        my $path = shift @_;
        my $code = pop @_;
        Carp::croak "Code must be code." unless ref $code eq 'CODE';
        my $arg = +{ code   => $code };
        if (@_) {
            $arg->{rule} = shift @_;
        }
        $router->connect($path, $arg)
    };
    *{"${pkg}::router"} = sub { $router };
}

package # hide from pause
    Amon2::Web::JSONAPI::Impl;

use Scalar::Util ();
use Data::Dumper ();

sub dispatch {
    my ($c) = @_;

    if (my $params = $c->router->match($c->req->env)) {
        if (exists($params->{method}) && $params->{method} ne $c->req->method) {
            my $res = $c->render_json({
                error => 'Method Not Allowed'
            });
            $res->code(405);
            return $res; # 405 Method Not Allowed
        } else {
            my $valids;

            # validate
            if (my $rule = $params->{rule}) {
                (my $res, $valids) = $c->validate_params($rule);
                return $res if $res;
            }

            # run code
            my $res = $params->{code}->($c, $params, $valids);

            # make response object
            if (ref $res eq 'HASH') {
                return $c->render_json($res); # succeeded
            } elsif (Scalar::Util::blessed $res) {
                return $res; # succeeded
            } elsif (ref $res eq 'ARRAY') {
                if ($Amon2::Web::JSONAPI::ALLOW_JSON_HIJACKING) {
                    return $c->render_json($res); # succeeded
                } else {
                    die "JSON API using array makes possibly JSON hijacking. Please use HashRef instead.";
                }
            } else {
                local $Data::Dumper::Terse = 1;
                local $Data::Dumper::Indent = 0;
                die("Unknown response: " . Data::Dumper::Dumper($res) . " : " . $c->req->path_info);
            }
        }
    } else {
        my $res = $c->render_json(+{
            error => 'Not Found'
        });
        $res->code(404);
        return $res; # not found...
    }
}

1;
__END__

=encoding utf8

=head1 NAME

Amon2::Web::JSONAPI - API dispatcher DSL for Amon2

=head1 SYNOPSIS

    package MyApp::Web;

    use Amon2::Web::JSONAPI -DFV;

    get '/api/v1/foo' => +{
        optional => [qw/company fax country/],
        required => [qw/fullname phone email address/],
    } => sub {
        my ($c, $args, $valids) = @_;
        # $args is a captured arguments from Router::Simple.
        # $valids is a hashref, contains valid parameters.
        ...
        return +{
            foo => 'bar',
        };
    };

    package main;

    my $psgi_app = MyApp::Web->to_app();

=head1 DESCRIPTION

Amon2::Web::JSONAPI provides JSON API DSL for Amon2.

You can write a JSON API very easily with parameter validation.

=head1 IMPORTING

You can import a Amon2::Web::JSONAPI with following form.

    use Amon2::Web::JSONAPI -DFV;

This code is same as

    use Amon2::Web::JSONAPI;
    use parent qw(Amon2::Web::JSONAPI::DFV);

=head1 FUNCTIONS

=over 4

=item any($path:Str[, $profile:HashRef], $code:CodeRef)

Handles in C<$path> with validator profile C<$profile>, and run C<$code>.

C<$path> is passed to L<Router::Simple>.

C<$profile> is a validator's profile in HashRef. Please look each valildator's manual for more details.

C<$code> gets three arguments.
C<$c> is a Amon2's context object.
C<$args> is a captured parameters by Router::Simple.
C<$valids> is a validated parameters by validators, normally.

You can omit the C<$profile> argument if the API doens't need to validate parameters.

I<Return Value>: useless.

=item get($path:Str[, $profile:HashRef], $code:CodeRef)

Same as C<any>, but invokes only in GET method.

When get Non-GET request, server returns 405 Method Not Allowed.

=item post($path:Str[, $profile:HashRef], $code:CodeRef)

Same as C<any>, but invokes only in POST method.

When get Non-POST request, server returns 405 Method Not Allowed.

=back

=head1 Making document from routes.

TBD

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

L<Amon2>, L<Data::FormValidator>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
