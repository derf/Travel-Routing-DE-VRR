package WWW::Efa::Error;

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};

# source: internal / efa.vrr.de
# type: internal: conf
#     efa.vrr.de: ambiguous / error / no data
sub new {
	my ($obj, $source, $type, $data) = @_;
	my $ref = {};

	$ref->{'source'} = $source;
	$ref->{'type'}   = $type;
	$ref->{'data'}   = $data;

	return bless($ref, $obj);
}

sub as_string {
	my ($self) = @_;
	my $ret;

	if ($self->{'source'} eq 'internal') {
		$ret = sprintf(
			"WWW::Efa config error: Wrong arg for option %s: %s\n%s\n",
			@{$self->{'data'}}
		);
	}
	elsif ($self->{'source'} eq 'efa.vrr.de') {
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
	}
	return $ret;
}

1;
