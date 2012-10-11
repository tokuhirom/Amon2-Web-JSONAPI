package Amon2::Web::JSONAPI::DFV;
use strict;
use warnings;
use 5.010001;
our $VERSION = '0.01';
# undocumented, but it's possible.
our $ALLOW_JSON_HIJACKING = 0;

use Router::Simple ();
use Amon2 ();
use Amon2::Web ();
use Carp ();

sub import {
    my $pkg = caller(0);
    my $router = Router::Simple->new();
    no strict 'refs';
    unless ($pkg->isa('Amon2')) {
        unshift @{"${pkg}::ISA"}, 'Amon2';
    }
    unshift @{"${pkg}::ISA"}, 'Amon2::Web';
    unshift @{"${pkg}::ISA"}, 'Amon2::Web::JSONAPI::DFV::Impl';
    $pkg->load_plugin(qw/Web::JSON/);
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
    Amon2::Web::JSONAPI::DFV::Impl;

use Data::FormValidator ();
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
                ( $valids, my $missings, my $invalids, my $unknowns ) =
                    Data::FormValidator->validate( $c->req->parameters->as_hashref_mixed, $rule );
                if (@$missings > 0 || @$invalids > 0) {
                    my $res = $c->render_json(
                        +{
                            error => +{
                                missings => $missings,
                                invalids => $invalids,
                            }
                        }
                    );
                    $res->code(400); # 400 Bad Request
                    return $res;
                }
            }

            # run code
            my $res = $params->{code}->($c, $valids, $params);

            # make response object
            if (ref $res eq 'HASH') {
                return $c->render_json($res); # succeeded
            } elsif (Scalar::Util::blessed $res) {
                return $res; # succeeded
            } elsif (ref $res eq 'ARRAY') {
                if ($Amon2::Web::JSONAPI::DFV::ALLOW_JSON_HIJACKING) {
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

Amon2::Web::JSONAPI::DFV - API dispatcher DSL for Amon2

=head1 SYNOPSIS

    package MyApp::Web;

    use Amon2::Web::JSONAPI::DFV;

    get '/api/v1/foo' => +{
        optional => [qw/company fax country/],
        required => [qw/fullname phone email address/],
    } => sub {
        my ($c, $valids, $args) = @_;
        # $valids is a hashref, contains valid parameters.
        # $args is a captured arguments from Router::Simple.
        ...
        return +{
            foo => 'bar',
        };
    };

    package main;

    my $psgi_app = MyApp::Web->to_app();

=head1 DESCRIPTION

Amon2::Web::JSONAPI::DFV provides API dispatcher DSL for Amon2 using Data::FormValidator.

You can write a JSON API very easily with parameter validation.

=head1 FUNCTIONS

=over 4

=item any($path:Str[, $profile:HashRef], $code:CodeRef)

Handles in C<$path> with Data::FormValidator profile C<$profile>, and run C<$code>.

C<$path> is passed to L<Router::Simple>.

C<$profile> is a L<Data::FormValidator>'s profile in HashRef. Please look L<Data::FormValidator>'s manual for more details.

C<$code> gets three arguments.
C<$c> is a Amon2's context object.
C<$valids> is a valid parameters by Data::FormValidator.
C<$args> is a captured parameters by Router::Simple.

You can omit the C<$profile> argument if the API doens't need to validate parameters.

I<Return Value>: useless.

=item get($path:Str[, $profile:HashRef], $code:CodeRef)

Same as C<any>, but invokes only in GET method.

When get Non-GET request, server returns 405 Method Not Allowed.

=item post($path:Str[, $profile:HashRef], $code:CodeRef)

Same as C<any>, but invokes only in POST method.

When get Non-POST request, server returns 405 Method Not Allowed.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

L<Amon2>, L<Data::FormValidator>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
