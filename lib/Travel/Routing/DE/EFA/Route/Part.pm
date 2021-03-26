package Travel::Routing::DE::EFA::Route::Part;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '2.20';

my %occupancy = (
	MANY_SEATS    => 1,
	FEW_SEATS     => 2,
	STANDING_ONLY => 3
);

Travel::Routing::DE::EFA::Route::Part->mk_ro_accessors(
	qw(arrival_platform arrival_stop
	  arrival_date arrival_time arrival_sdate arrival_stime delay
	  departure_platform
	  departure_stop departure_date departure_time departure_sdate
	  departure_stime
	  footpath_duration footpath_type
	  occupancy
	  train_destination train_line train_product
	  )
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	if ( $ref->{occupancy} and exists $occupancy{ $ref->{occupancy} } ) {
		$ref->{occupancy} = $occupancy{ $ref->{occupancy} };
	}
	else {
		delete $ref->{occupancy};
	}

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

sub is_cancelled {
	my ($self) = @_;

	if ( $self->{delay} and $self->{delay} eq '-9999' ) {
		return 1;
	}
	return;
}

# DEPRECATED
sub extra {
	my ($self) = @_;

	my @ret = map { $_->summary } @{ $self->{regular_notes} // [] };

	return @ret;
}

sub regular_notes {
	my ($self) = @_;

	if ( $self->{regular_notes} ) {
		return @{ $self->{regular_notes} };
	}
	return;
}

sub current_notes {
	my ($self) = @_;

	if ( $self->{current_notes} ) {
		return @{ $self->{current_notes} };
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

		if ( $part->regular_notes ) {
			say join( "\n", $part->regular_notes );
		}
		if ( $part->current_notes ) {
			say join( "\n", map [ $_->{summary} ] $part->current_notes );
		}

		printf(
			"%s at %s -> %s at %s, via %s to %s",
			$part->departure_time, $part->departure_stop,
			$part->arrival_time,   $part->arrival_stop,
			$part->train_line,     $part->train_destination,
		);
	}

=head1 VERSION

version 2.20

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

=item $part->current_notes

Remarks about unscheduled changes to the line serving this connaction part,
such as cancelled stops. Most times, the EFA service does not include this
information in its route calculations.

Returns a list of Travel::Routing::DE::EFA::Route::Message(3pm) objects.

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

=item $part->footpath_duration

Walking duration when transferring before / after / during this trip
in minutes. The meaning depends on the value of B<footpath_type>.

=item $part->footpath_parts

Returns a list of [I<type>, I<level>] arrayrefs describing the
footpath. For instance, ["ESCALATOR", "UP"], ["LEVEL", "LEVEL"],
["STAIRS", "UP"] means first taking an escalator up, then walking a while,
and then taking a flight of stairs up again.

The content of I<type> and I<level> comes directly from the EFA backend. At
the moment, the following values are known:

=over

=item type: ESCALATOR, LEVEL, STAIRS

=item level: DOWN, LEVEL, UP

=back

=item $part->footpath_type

type of this footpath, passed through from the EFA backend. The value
"AFTER" indicates a footpath (transfer) after this route part. The value
"IDEST" indicates that this route part already is a footpath (aka a walking
connection between two stops), so the B<footpath> accessors contain redundant
information. Other values such as "BEFORE" may also be returned, but this is
unknown at this point.

=item $part->is_cancelled

Returns true if this part of the route has been cancelled (i.e., the entire
route is probably useless), false otherwise.  For unknown reasons, EFA may
sometimes return routes which contain cancelled departures.

=item $part->occupancy

Returns expected occupancy, if available. Values range from 1 (low occupancy)
to 3 (very high occupancy).

=item $part->regular_notes

Remarks about the line serving this connaction part. Returns a list of
Travel::Routing::DE::EFA::Route::Message(3pm) objects.

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

Returns a list of C<< [ "DD.MM.YYYY", "HH:MM", stop, platform ] >> arrayrefs
encoding the stops passed between B<departure_stop> and B<arrival_stop>,
if supported by the backend. Returns nothing / an empty list otherwise.

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

Travel::Routing::DE::EFA::Route::Message(3pm), Travel::Routing::DE::EFA(3pm),
Class::Accessor(3pm).

=head1 AUTHOR

Copyright (C) 2011-2021 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This program is licensed under the same terms as Perl itself.
