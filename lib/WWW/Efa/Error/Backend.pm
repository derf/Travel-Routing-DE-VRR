package WWW::Efa::Error::Backend;

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};

sub new {
	my ($obj, $type, $data) = @_;
	my $ref = {};

	$ref->{'type'}   = $type;
	$ref->{'data'}   = $data;

	return bless($ref, $obj);
}

sub as_string {
	my ($self) = @_;
	my $ret;

	given ($self->{'type'}) {
		when ('no data') {
			$ret = "WWW::Efa: efa.vrr.de returned no data\n";
		}
		when ('ambiguous') {
			$ret = sprintf(
				"WWW::Efa: efa.vrr.de: Ambiguous input for %s:\n",
				shift(@{$self->{'data'}}),
			);
			foreach my $possible (@{$self->{'data'}}) {
				$ret .= "\t${possible}\n";
			}
		}
		when ('error') {
			$ret = sprintf(
				"WWW::Efa: efa.vrr.de error:\n%s\n",
				$self->{'data'},
			);
		}
	}
	return $ret;
}

1;
