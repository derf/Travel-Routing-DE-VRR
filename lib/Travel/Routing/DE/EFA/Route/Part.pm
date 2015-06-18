package Travel::Routing::DE::EFA::Route::Part;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '2.11';

Travel::Routing::DE::EFA::Route::Part->mk_ro_accessors(
	qw(arrival_platform arrival_stop
	  arrival_date arrival_time arrival_sdate arrival_stime delay
	  departure_platform
	  departure_stop departure_date departure_time departure_sdate
	  departure_stime
	  footpath_duration footpath_type
	  train_destination train_line train_product
	  )
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub arrival_routemaps {
	my ($self) = @_;

	return @{ $self->{arrival_routemaps} };
}

sub arrival_stationmaps {
	my ($self) = @_;

	return @{ $self->{arrival_stationmaps} };
}

sub arrival_stop_and_platform {
	my ($self) = @_;

	if ( length( $self->arrival_platform ) ) {
		return
		  sprintf( '%s: %s', $self->get(qw(arrival_stop arrival_platform)) );
	}
	return $self->arrival_stop;
}

sub departure_routemaps {
	my ($self) = @_;

	return @{ $self->{departure_routemaps} };
}

sub departure_stationmaps {
	my ($self) = @_;

	return @{ $self->{departure_stationmaps} };
}

sub departure_stop_and_platform {
	my ($self) = @_;

	if ( length( $self->departure_platform ) ) {

		return
		  sprintf( '%s: %s',
			$self->get(qw(departure_stop departure_platform)) );
	}
	return $self->departure_stop;
}

sub footpath_parts {
	my ($self) = @_;

	if ( $self->{footpath_parts} ) {
		return @{ $self->{footpath_parts} };
	}
	return;
}

# DEPRECATED
sub extra {
	my ($self) = @_;

	return @{ $self->{sched_info} // [] };
}

sub sched_info {
	my ($self) = @_;

	if ( $self->{sched_info} ) {
		return @{ $self->{sched_info} };
	}
	return;
}

sub current_info {
	my ($self) = @_;

	if ( $self->{current_info} ) {
		return @{ $self->{current_info} };
	}
	return;
}

sub via {
	my ($self) = @_;

	return @{ $self->{via} // [] };
}

1;

__END__

=head1 NAME

Travel::Routing::DE::EFA::Route::Part - Describes one connection between two
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

version 2.11

=head1 DESCRIPTION

B<Travel::Routing::DE::EFA::Route::Part> holds one specific connection (without
interchanges) between two points.  It specifies the start/stop point and time,
the train line and its destination, and optional additional data.

It is usually obtained by a call to Travel::Routing::DE::EFA::Route(3pm)'s
B<parts> method.

=head1 METHODS

=head2 ACCESSORS

"Actual" in the description means that the delay (if available) is already
included in the calculation, "Scheduled" means it isn't.

=over

=item $part->arrival_stop

arrival stop (city name plus station name)

=item $part->arrival_platform

arrival platform (either "Gleis x" or "Bstg. x")

=item $part->arrival_stop_and_platform

"stop: platform" concatenation

=item $part->arrival_date

Actual arrival date in DD.MM.YYYY format

=item $part->arrival_time

Actual arrival time in HH:MM format

=item $part->arrival_sdate

Scheduled arrival date in DD.MM.YYYY format

=item $part->arrival_stime

Scheduled arrival time in HH:MM format

=item $part->arrival_routemaps

List of URLs, may be empty. Each URL poinst to a transfer map for the arrival
station, usually outlining how to transfer from this train to the next one
(if applicable).

=item $part->arrival_stationmaps

List of URLs, may be empty. Each URL points to an HTML map of the arrival
station.

=item $part->delay

delay in minutes, 0 if unknown

=item $part->departure_stop

departure stop (city name plus station name)

=item $part->departure_platform

departure platform (either "Gleis x" or "Bstg. x")

=item $part->departure_stop_and_platform

"stop: platform" concatenation

=item $part->departure_date

Actual departure date in DD.MM.YYYY format

=item $part->departure_time

Actual departure time in HH:MM format

=item $part->departure_sdate

Scheduled departure date in DD.MM.YYYY format

=item $part->departure_stime

Scheduled departure time in HH:MM format

=item $part->departure_routemaps

List of URLs, may be empty. Each URL points to a PDF a transfer map for the
departure station, usually outlining how to transfer from thep previous train
(if applicable) to this one.

=item $part->departure_stationmaps

List of URLs, may be empty. Each URL poinst to an HTML map of the departure
station.

=item $part->extra

Additional information about the connection.  Returns a list of
newline-terminated strings

=item $part->train_destination

Destination of the line providing the connection. May be empty.

=item $part->train_line

Name / number of the line. May be empty.

=item $part->train_product

Usually the prefix of B<train_line>, for instance C<< U-Bahn >> or
C<< Niederflurstrab >>. However, it may also contain special values such as
C<< FuE<szlig>weg >> (for a direct connection without transit vehicles) or
C<< nicht umsteigen >> (in case a vehicle changes its line number at a stop).
In those cases, B<train_destination> and B<train_line> are usually empty.

=item $part->via

List of stops passed between departure_stop and arrival_stop, as
C<< [ "DD.MM.YYYY", "HH:MM", stop, platform ] >> hashrefs.

May be empty, these are not always reported by efa.vrr.de.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

$part->via does not work reliably.

=head1 SEE ALSO

Travel::Routing::DE::EFA(3pm), Class::Accessor(3pm).

=head1 AUTHOR

Copyright (C) 2011-2015 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
