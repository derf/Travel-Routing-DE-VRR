#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

eval "use Test::Synopsis";

if ($@) {
	plan skip_all => 'Test::Synopsis required for testing';
}

all_synopsis_ok();
