package WWW::Efa::Error::Setup;

=head1 NAME

WWW::Efa::Error::Setup - WWW::Efa error, happened in ->new()

=head1 SYNOPSIS

    use WWW::Efa::Error::Setup;

    my $error = WWW::Efa::Error::Setup->new(
        'max_interchanges', '-1', 'Must be positive'
    );

    die $error->as_string();
    # WWW::Efa setup error: Wrong arg for option max_interchanges: -1
    # Must be positive

=head1 DESCRIPTION

Class for all WWW::Efa-internal errors occuring during initialization. Usually
caused by missing or invalid setup arguments.

=cut

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

=head1 METHODS

=head2 $error->as_string()

Return the error as string, can directly be displayed to the user

=cut

sub as_string {
	my ($self) = @_;

	return sprintf(
		"WWW::Efa setup error: Wrong arg for option %s: %s\n%s\n",
		@{$self}{'key', 'value', 'message'},
	);
}

=head2 $error->option()

Returns the option which caused the error.

=head2 $error->value()

Returns the value which caused the error.

=head2 $error->message()

Returns a message describing what went wrong and how to fix it.

=cut

sub option  { return $_[0]->{'key'}     }
sub value   { return $_[0]->{'value'}   }
sub message { return $_[0]->{'message'} }

1;
