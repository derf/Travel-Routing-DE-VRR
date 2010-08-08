package WWW::Efa::Error::Setup;

use strict;
use warnings;
use 5.010;

use base 'Exporter';

our @EXPORT_OK = qw{};

sub new {
	my ($obj, $key, $value, $msg) = @_;
	my $ref = {};

	$ref->{'key'}     = $key;
	$ref->{'value'}   = $value;
	$ref->{'message'} = $msg;

	return bless($ref, $obj);
}

sub as_string {
	my ($self) = @_;
	my $ret;

	return sprintf(
		"WWW::Efa setup error: Wrong arg for option %s: %s\n%s\n",
		@{$self}{'key', 'value', 'message'},
	);
}

1;
