#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

eval "use Test::Synopsis";

if ($@) {
	plan skip_all => 'Test::Synopsis required for testing';
}
else {
	plan tests => 1;
}

for my $m (qw(lib/WWW/Efa.pm)) {
	synopsis_ok($m);
}
