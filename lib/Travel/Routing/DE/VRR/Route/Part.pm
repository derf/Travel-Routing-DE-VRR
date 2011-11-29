package Travel::Routing::DE::VRR::Route::Part;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '1.06';

Travel::Routing::DE::VRR::Route::Part->mk_ro_accessors(
	qw(arrival_platform arrival_stop
	  arrival_date arrival_time arrival_sdate arrival_stime
	  delay departure_platform departure_stop
	  departure_date departure_time departure_sdate departure_stime
	  train_line train_destination
	  )
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub arrival_stop_and_platform {
	my ($self) = @_;

	return sprintf( '%s: %s', $self->get(qw(arrival_stop arrival_platform)) );
}

sub departure_stop_and_platform {
	my ($self) = @_;

	return
	  sprintf( '%s: %s', $self->get(qw(departure_stop departure_platform)) );
}

sub extra {
	my ($self) = @_;

	return @{ $self->{extra} // [] };
}

1;

__END__

=head1 NAME

Travel::Routing::DE::VRR::Route::Part - Describes one connection between two
points, without interchanges

=head1 SYNOPSIS

	for my $part ( $route->parts ) {

		if ( $part->extra ) {
			say join( "\n", $part->extra );
		}

		printf(
			"%s at %s -> %s at %s, via %s to %s",
			$part->departure_time, $part->departure_stop,
			$part->arrival_time,   $part->arrival_stop,
			$part->train_line,     $part->train_destination,
		);
	}

=head1 VERSION

version 1.06

=head1 DESCRIPTION

B<Travel::Routing::DE::VRR::Route::Part> holds one specific connection (without
interchanges) between two points.  It specifies the start/stop point and time,
the train line and its destination, and optional additional data.

It is usually obtained by a call to Travel::Routing::DE::VRR::Route(3pm)'s
B<parts> method.

=head1 METHODS

=over

=item $part = Travel::Routing::DE::VRR::Route::Part->new(I<%data>)

Creates a new Travel::Routing::DE::VRR::Route::Part object. I<data> consists of:

=over

=item B<arrival_time> => I<HH>:I<MM>

Arrival time

=item B<arrival_stop> => I<name>

Arrival stop (city plus station / address)

=item B<departure_time> => I<HH:MM>

Departure time

=item B<departure_stop> => I<name>

Departure stop (city plus station / address)

=item B<train_destination> => I<name>

Destination of the train connecting the stops

=item B<train_line> => I<name>

The train's line name.

=item B<extra> => B<[> [ I<line1>, [ I<line2> [ I<...> ] ] ] B<]>

Additional information about this connection.  Array-ref of newline-terminated
strings.

=back

=item $part->get(I<name>)

Returns the value of I<name> (B<arrival_time>, B<arrival_stop> etc., see
B<new>).

Each of these I<names> also has an accessor. So C<< $part->departure_time() >>
is the same as C<< $part->get('departure_time') >>.

=item $part->extra()

Returns a list of additional information about this route part, if provided.
Returns an empty list otherwise.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Routing::DE::VRR(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
