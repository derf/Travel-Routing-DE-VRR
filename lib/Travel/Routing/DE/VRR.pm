package Travel::Routing::DE::VRR;

use strict;
use warnings;
use 5.010;

our $VERSION = '2.22';

use parent 'Travel::Routing::DE::EFA';

sub new {
	my ( $class, %opt ) = @_;

	$opt{efa_url} = 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2';

	return $class->SUPER::new(%opt);
}

1;

__END__

=head1 NAME

Travel::Routing::DE::VRR - unofficial interface to the efa.vrr.de German itinerary service

=head1 SYNOPSIS

	use Travel::Routing::DE::VRR;

	my $efa = Travel::Routing::DE::VRR->new(
		origin      => [ 'Essen',    'HBf' ],
		destination => [ 'Duisburg', 'HBf' ],
	);

	for my $route ( $efa->routes ) {
		for my $part ( $route->parts ) {
			printf(
				"%s at %s -> %s at %s, via %s to %s",
				$part->departure_time, $part->departure_stop,
				$part->arrival_time,   $part->arrival_stop,
				$part->train_line,     $part->train_destination,
			);
		}
		print "\n\n";
	}

=head1 VERSION

version 2.22

=head1 DESCRIPTION

B<Travel::Routing::DE::VRR> is a client for the efa.vrr.de web interface.
You pass it the start/stop of your journey, maybe a time and a date and more
details, and it returns the up-to-date scheduled connections between those two
stops.

=head1 METHODS

=over

=item $efa = Travel::Routing::DE::VRR->new(I<%opts>)

Returns a new Travel::Routing::DE::VRR object and sets up its POST data via
I<%opts>.

Calls Travel::Routing::DE::EFA->new with the appropriate B<efa_url>, all
I<%opts> are passed on. See Travel::Routing::DE::EFA(3pm) for valid
parameters and methods

=back

When encountering an error, Travel::Routing::DE::VRR throws a
Travel::Routing::DE::EFA::Exception(3pm) object.

=head1 DEPENDENCIES

=over

=item * Travel::Routing::DE::EFA(3pm)

=item * LWP::UserAgent(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

=over

=item * Travel::Routing::DE::EFA(3pm)

=back

=head1 AUTHOR

Copyright (C) 2009-2021 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This program is licensed under the same terms as Perl itself.
