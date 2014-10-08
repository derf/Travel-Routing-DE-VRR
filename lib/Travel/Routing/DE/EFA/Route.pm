package Travel::Routing::DE::EFA::Route;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

use Travel::Routing::DE::EFA::Route::Part;

our $VERSION = '2.08';

Travel::Routing::DE::EFA::Route->mk_ro_accessors(
	qw(duration ticket_text ticket_type fare_adult fare_child vehicle_time));

sub new {
	my ( $obj, $info, @parts ) = @_;

	my $ref = $info;

	for my $part (@parts) {
		push(
			@{ $ref->{parts} },
			Travel::Routing::DE::EFA::Route::Part->new( %{$part} )
		);
	}

	return bless( $ref, $obj );
}

sub parts {
	my ($self) = @_;

	return @{ $self->{parts} };
}

1;

__END__

=head1 NAME

Travel::Routing::DE::EFA::Route - Single route (connection) between two points

=head1 SYNOPSIS

	for my $route ( $efa->routes ) {
		for my $part ( $route->parts ) {
			# $part is a Travel::Routing::DE::EFA::Route::Part object
		}
	}

=head1 VERSION

version 2.08

=head1 DESCRIPTION

Travel::Routing::DE::EFA::Route describes a single method of getting from one
point to another.  It holds a bunch of Travel::Routing::DE::EFA::Route::Part(3pm)
objects describing the parts of the route in detail.  Each part depends on the
previous one.

You usually want to acces it via C<< $efa->routes >>.

=head1 METHODS

=head2 ACCESSORS

=over

=item $route->duration

route duration as string in HH:MM format

=item $route->parts

Returns a list of Travel::Routing::DE::EFA::Route::Part(3pm) elements describing
the actual route

=item $route->ticket_type

Type of the required ticket for this route, if available (empty string otherwise)

=item $route->fare_adult

ticket price for an adult in EUR

=item $route->fare_child

ticket price for a child in EUR

=item $route->vehicle_time

on-vehicle time (excluding waiting time) of the route in minutes

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

None.

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Routing::DE::EFA(3pm), Travel::Routing::DE::EFA::Route::Part(3pm).

=head1 AUTHOR

Copyright (C) 2011-2014 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
