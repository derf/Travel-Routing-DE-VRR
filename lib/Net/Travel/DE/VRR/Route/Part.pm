package Net::Travel::DE::VRR::Route::Part;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '1.3';

Net::Travel::DE::VRR::Route::Part->mk_ro_accessors(
	qw(arr_stop arr_time dep_stop dep_time train_line train_dest));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub extra {
	my ($self) = @_;

	return @{ $self->{extra} // [] };
}

1;

__END__

=head1 NAME

Net::Travel::DE::VRR::Route::Part - Describes one connection between two
points, without interchanges

=head1 SYNOPSIS

=head1 VERSION

version 0.3

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
