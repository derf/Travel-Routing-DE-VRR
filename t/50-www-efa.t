#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 131;

BEGIN {
	use_ok('WWW::Efa');
}
require_ok('WWW::Efa');

sub efa_conf {
	my $ret = {
		from => ['Essen', 'HBf'],
		to   => ['Koeln', 'HBf'],
	};
	foreach my $p (@_) {
		$ret->{$p->[0]} = $p->[1];
	}
	return $ret;
}

sub efa_post {
	my $ret = {
		place_origin => 'Essen',
		name_origin => 'HBf',
		type_origin => 'stop',
		place_destination => 'Koeln',
		name_destination => 'HBf',
		type_destination => 'stop',
	};
	foreach my $p (@_) {
		$ret->{$p->[0]} = $p->[1];
	}
	return $ret;
}

sub efa_new {
	return new_ok(
		'WWW::Efa' => [%{efa_conf(@_)}]
	);
}

sub is_efa_post {
	my ($ck, $cv, @post) = @_;
	my $efa = efa_new([$ck, $cv]);

	is_deeply(
		$efa->{'config'}, efa_conf([$ck, $cv]),
		"$ck => $cv: conf ok",
	);

	is(
		$efa->{'error'}, undef,
		"$ck => $cv: No error",
	);
	
	is_deeply(
		$efa->{'post'}, efa_post(@post),
		"$ck => $cv: POST ok",
	);
}

sub is_efa_err {
	my ($key, $val, $str) = @_;
	my $efa = efa_new([$key, $val]);

	my $val_want = $val;

	if (ref $val eq 'ARRAY') {
		$val_want = join(q{ }, @{$val});
	}

	is_deeply(
		$efa->{'config'}, efa_conf([$key, $val]),
		"conf ok: $key => $val",
	);

	isa_ok($efa->{'error'}, 'WWW::Efa::Error::Setup');

	is(
		$efa->{'error'}->option(), $key,
		"$key => $val: Error: Correct key",
	);
	is(
		$efa->{'error'}->value(), $val_want,
		"$key => $val: Error: Correct valuef",
	);
	is(
		$efa->{'error'}->message(), $str,
		"$key => $val: Error: String is '$str'",
	);
}

is_efa_post('ignored', 'ignored');

my $efa = new_ok('WWW::Efa' => []);
isa_ok($efa->{'error'}, 'WWW::Efa::Error::Setup');
is($efa->{'error'}->{'key'}, 'place');
is($efa->{'error'}->{'value'}, 'origin');
is($efa->{'error'}->{'message'}, 'Need at least two elements');

is_efa_post(
	'via', ['MH', 'HBf'],
	['place_via', 'MH'],
	['name_via', 'HBf'],
	['type_via', 'stop'],
);

is_efa_post(
	'from', ['D', 'Fuerstenwall 232', 'address'],
	['place_origin', 'D'],
	['name_origin', 'Fuerstenwall 232'],
	['type_origin', 'address'],
);

is_efa_post(
	'depart', '22:23',
	['itdTripDateTimeDepArr', 'dep'],
	['itdTimeHour', '22'],
	['itdTimeMinute', '23'],
);

is_efa_post(
	'arrive', '16:38',
	['itdTripDateTimeDepArr', 'arr'],
	['itdTimeHour', '16'],
	['itdTimeMinute', '38'],
);

is_efa_err(
	'depart', '37:00',
	'Must match HH:MM',
);

is_efa_err(
	'depart', '07',
	'Must match HH:MM',
);

is_efa_post(
	'date', '2.10.2009',
	['itdDateDay', '2'],
	['itdDateMonth', '10'],
	['itdDateYear', '2009'],
);

is_efa_post(
	'date', '26.12.',
	['itdDateDay', '26'],
	['itdDateMonth', '12'],
	['itdDateYear', (localtime(time))[5] + 1900],
);

is_efa_err(
	'date', '42.5.2003',
	'Must match DD.MM.[YYYY]'
);

is_efa_err(
	'date', '7.',
	'Must match DD.MM.[YYYY]'
);

is_efa_post(
	'exclude', [qw[zug]],
	['inclMOT_0', undef],
);

is_efa_post(
	'exclude', [qw[stadtbus schiff ast]],
	['inclMOT_5',  undef],
	['inclMOT_9',  undef],
	['inclMOT_10', undef],
);

is_efa_err(
	'exclude', [qw[sonstige invalid]],
	'Must consist of '
	. 'zug s-bahn u-bahn stadtbahn tram stadtbus regionalbus '
	. 'schnellbus seilbahn schiff ast sonstige',
);

is_efa_post(
	'prefer', 'speed',
	['routeType', 'LEASTTIME'],
);

is_efa_post(
	'prefer', 'nowait',
	['routeType', 'LEASTINTERCHANGE'],
);

is_efa_post(
	'prefer', 'nowalk',
	['routeType', 'LEASTWALKING'],
);

is_efa_err(
	'prefer', 'invalid',
	'Must be either speed, nowait or nowalk',
);

is_efa_post(
	'include', 'local',
	['lineRestriction', 403],
);

is_efa_post(
	'include', 'ic',
	['lineRestriction', 401],
);

is_efa_post(
	'include', 'ice',
	['lineRestriction', 400],
);

is_efa_err(
	'include', 'invalid',
	'Must be one of local/ic/ice',
);

is_efa_post(
	'walk_speed', 'normal',
	['changeSpeed', 'normal'],
);

is_efa_err(
	'walk_speed', 'invalid',
	'Must be normal, fast or slow',
);

is_efa_post(
	'max_interchanges', 5,
	['maxChanges', 5],
);

is_efa_post(
	'proximity', 1,
	['useProxFootSearch', 1],
);

is_efa_post(
	'bike', 1,
	['bikeTakeAlong', 1],
);
