#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 59;

BEGIN {
	use_ok('Travel::Routing::DE::VRR');
}
require_ok('Travel::Routing::DE::VRR');

sub efa_conf {
	my $ret = {
		origin      => ['Essen', 'HBf'],
		destination => ['Koeln', 'HBf'],
		lwp_options => {},
		submit      => 0,
	};
	foreach my $p (@_) {
		$ret->{$p->[0]} = $p->[1];
	}
	return $ret;
}

sub efa_new {
	return new_ok(
		'Travel::Routing::DE::VRR' => [%{efa_conf(@_)}]
	);
}

sub is_efa_post {
	my ($ck, $cv, @post) = @_;
	my $efa = efa_new([$ck, $cv]);

	my $ok = 1;

	is_deeply(
		$efa->{'config'}, efa_conf([$ck, $cv]),
		"$ck => $cv: conf ok",
	);

	foreach my $ref (@post) {
		my ($key, $value) = @{$ref};
		if (not defined $efa->{'post'}->{"key"} and
				not defined $value) {
			next;
		}
		if ($efa->{'post'}->{"$key"} ne $value) {
			$ok = 0;
			last;
		}
	}
	ok(
		$ok,
		"$ck => $cv: POST okay",
	);
}

sub is_efa_err {
	my ($key, $val, $str) = @_;
	return; # FIXME error handling
	my $efa = efa_new([$key, $val]);

	my $val_want = $val;

	if (ref $val eq 'ARRAY') {
		$val_want = join(q{ }, @{$val});
	}

	is_deeply(
		$efa->{'config'}, efa_conf([$key, $val]),
		"conf ok: $key => $val",
	);

	# FIXME actual error tests

}

is_efa_post('ignored', 'ignored');

my $efa;

is_efa_post(
	'via', ['MH', 'HBf'],
	['place_via', 'MH'],
	['name_via', 'HBf'],
	['type_via', 'stop'],
);

is_efa_post(
	'origin', ['D', 'Fuerstenwall 232', 'address'],
	['place_origin', 'D'],
	['name_origin', 'Fuerstenwall 232'],
	['type_origin', 'address'],
);

is_efa_post(
	'departure_time', '22:23',
	['itdTripDateTimeDepArr', 'dep'],
	['itdTimeHour', '22'],
	['itdTimeMinute', '23'],
);

is_efa_post(
	'arrival_time', '16:38',
	['itdTripDateTimeDepArr', 'arr'],
	['itdTimeHour', '16'],
	['itdTimeMinute', '38'],
);

is_efa_err(
	'departure_time', '37:00',
	'Must match HH:MM',
);

is_efa_err(
	'departure_time', '07',
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
	'Invalid day',
);

is_efa_err(
	'date', '7.',
	'Invalid month',
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
	'select_interchange_by', 'speed',
	['routeType', 'LEASTTIME'],
);

is_efa_post(
	'select_interchange_by', 'waittime',
	['routeType', 'LEASTINTERCHANGE'],
);

is_efa_post(
	'select_interchange_by', 'distance',
	['routeType', 'LEASTWALKING'],
);

is_efa_err(
	'select_interchange_by', 'invalid',
	'Must be either speed, nowait or nowalk',
);

is_efa_post(
	'train_type', 'local',
	['lineRestriction', 403],
);

is_efa_post(
	'train_type', 'ic',
	['lineRestriction', 401],
);

is_efa_post(
	'train_type', 'ice',
	['lineRestriction', 400],
);

is_efa_err(
	'train_type', 'invalid',
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
	'use_near_stops', 1,
	['useProxFootSearch', 1],
);

is_efa_post(
	'with_bike', 1,
	['bikeTakeAlong', 1],
);
