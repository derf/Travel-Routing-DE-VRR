package Travel::Routing::DE::VRR::Route;

use strict;
use warnings;
use 5.010;

use Travel::Routing::DE::VRR::Route::Part;

our $VERSION = '1.3';

sub new {
	my ( $obj, @parts ) = @_;

	my $ref = {};

	for my $part (@parts) {
		push(
			@{ $ref->{parts} },
			Travel::Routing::DE::VRR::Route::Part->new( %{$part} )
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

Travel::Routing::DE::VRR::Route - Single route (connection) between two points

=head1 SYNOPSIS

	for my $route ( $efa->routes ) {
		for my $part ( $route->parts ) {
			# $part is a Travel::Routing::DE::VRR::Route::Part object
		}
	}

=head1 VERSION

version 1.3

=head1 DESCRIPTION

Travel::Routing::DE::VRR::Route describes a single method of getting from one
point to another.  It holds a bunch of Travel::Routing::DE::VRR::Route::Part(3pm)
objects describing the parts of the route in detail.  Each part depends on the
previous one.

You usually want to acces it via C<< $efa->routes() >>.

=head1 METHODS

=over

=item my $route = Travel::Routing::DE::VRR::Route->new(I<@parts>)

Creates a new Travel::Routing::DE::VRR::Route elements consisting of I<parts>,
which are Travel::Routing::DE::VRR::Route::Part elements.

=item $route->parts()

Returns a list of Travel::Routing::DE::VRR::Route::Part(3pm) elements describing
the actual route.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

None.

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Routing::DE::VRR(3pm), Travel::Routing::DE::VRR::Route::Part(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
