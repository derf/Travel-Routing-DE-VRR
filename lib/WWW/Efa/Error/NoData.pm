package WWW::Efa::Error::NoData;

=head1 NAME

WWW::Efa::Error::NoData - WWW::Efa error, efa.vrr.de returned no data

=head1 SYNOPSIS

    use WWW::Efa::Error::Setup;

    my $error = WWW::Efa::Error::NoData->new();

    die $error->as_string();
    # WWW::Efa error: No data returned by efa.vrr.de

=head1 DESCRIPTION

efa.vrr.de returned no parsable data

=cut

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};
our @ISA = ('WWW::Efa::Error');

sub new {
	my ($obj) = @_;
	my $ref = {};

	return bless($ref, $obj);
}

=head1 METHODS

=head2 $error->as_string()

Return the error as string, can directly be displayed to the user

=cut

sub as_string {
	return "WWW::Efa error: No data returned by efa.vrr.de\n";
}

1;
