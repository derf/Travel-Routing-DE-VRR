package Net::Travel::DE::VRR::Route;

use strict;
use warnings;
use 5.010;

use Net::Travel::DE::VRR::Route::Part;

our $VERSION = '1.3';

sub new {
	my ( $obj, @parts ) = @_;

	my $ref = {};

	for my $part (@parts) {
		push(
			@{ $ref->{parts} },
			Net::Travel::DE::VRR::Route::Part->new( %{$part} )
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

Net::Travel::DE::VRR::Route - Single route (connection) between two points

=head1 SYNOPSIS

=head1 VERSION

version 1.3

=head1 DESCRIPTION

=head1 METHODS

=over

=back

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=back

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
