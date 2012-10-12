package Amon2::Web::JSONAPI::DFV;
use strict;
use warnings;
use 5.010001;
our $VERSION = '0.01';

use Data::FormValidator ();

sub validate_params {
    my ($self, $rule) = @_;

    ( my $valids, my $missings, my $invalids, my $unknowns ) =
        Data::FormValidator->validate( $self->req->parameters->as_hashref_mixed, $rule );
    if (@$missings > 0 || @$invalids > 0) {
        my $res = $self->render_json(
            +{
                error => +{
                    missings => $missings,
                    invalids => $invalids,
                }
            }
        );
        $res->code(400); # 400 Bad Request
        return ($res, undef);
    } else {
        return (undef, $valids);
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

=head1 Making document from routes.


=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

L<Amon2>, L<Data::FormValidator>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
