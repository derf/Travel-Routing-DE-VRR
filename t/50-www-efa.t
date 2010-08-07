#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 6;

BEGIN {
	use_ok('WWW::Efa');
}
require_ok('WWW::Efa');

my $conf_default = {
	from => ['Essen', 'HBf'],
	to   => ['Koeln', 'HBf'],
};
my $post_default = {
	place_origin => 'Essen',
	name_origin => 'HBf',
	type_origin => 'stop',
	place_destination => 'Koeln',
	name_destination => 'HBf',
	type_destination => 'stop',
};

my $efa = new_ok('WWW::Efa' => [%{$conf_default}]);

can_ok($efa, qw{new submit parse connections});

is_deeply($efa->{'config'}, $conf_default);
is_deeply($efa->{'post'}, $post_default);

$efa = WWW::Efa->new();
