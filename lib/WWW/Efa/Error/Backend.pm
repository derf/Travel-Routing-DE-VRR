package WWW::Efa::Error::Backend;

=head1 NAME

WWW::Efa::Error::Backend - WWW::Efa unknown error from efa.vrr.de

=head1 SYNOPSIS

    use WWW::Efa::Error::Backend;

    my $error = WWW::Efa::Error::Backend->new(
        'Yadda Yadda'
    );

    die $error->as_string();
    # WWW::Efa error from efa.vrr.de:
    # Yadda Yadda

=head1 DESCRIPTION

Received an unknown error from efa.vrr.de

=cut

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};
our @ISA = ('WWW::Efa::Error');

sub new {
	my ($obj, $msg) = @_;
	my $ref = {};

	$ref->{'message'} = $msg;

	return bless($ref, $obj);
}

=head1 METHODS

=head2 $error->as_string()

Return the error as string, can directly be displayed to the user

=cut

sub as_string {
	my ($self) = @_;

	return sprintf(
		"WWW::Efa error from efa.vrr.de:\n%s\n",
		$self->{'message'},
	);
}

1;
