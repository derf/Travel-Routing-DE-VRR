package WWW::Efa::Error::Ambiguous;

=head1 NAME

WWW::Efa::Error::Ambiguous - WWW::Efa error, ambiguous to/from/via input

=head1 SYNOPSIS

    use WWW::Efa::Error::Ambiguous;

    my $error = WWW::Efa::Error::Ambiguous->new(
        'name_origin', 'Bredeney', 'Bredeney Friedhof'
    );

    die $error->as_string();
    # WWW::Efa error: ambiguous input for name_origin:
    #     Bredeney
    #     Bredeney Friedhof

=head1 DESCRIPTION

Class for all WWW::Efa-internal errors occuring during initialization. Usually
caused by missing or invalid setup arguments.

=cut

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};
our @ISA = ('WWW::Efa::Error');

sub new {
	my ($obj, $key, @possible) = @_;
	my $ref = {};

	$ref->{'key'}      = $key;
	$ref->{'possible'} = \@possible;

	return bless($ref, $obj);
}

=head1 METHODS

=head2 $error->as_string()

Return the error as string, can directly be displayed to the user

=cut

sub as_string {
	my ($self) = @_;

	my $ret = sprintf(
		"WWW::Efa error: ambiguous input for %s:\n",
		$self->{'key'},
	);

	foreach my $value (@{$self->{'possible'}}) {
		$ret .= "\t$value\n";
	}

	return $ret;
}

1;
