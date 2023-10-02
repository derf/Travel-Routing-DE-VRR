#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 67;
use Test::Fatal;

BEGIN {
	use_ok('Travel::Routing::DE::VRR');
}
require_ok('Travel::Routing::DE::VRR');

sub efa_conf {
	my $ret = {
		efa_url     => 'https://app.vrr.de/vrrstd/XML_TRIP_REQUEST2',
		origin      => [ 'Essen', 'HBf' ],
		destination => [ 'Koeln', 'HBf' ],
		rm_base     => 'https://app.vrr.de/vrrstd/',
		sm_base     => 'https://app.vrr.de/download/envmaps/',
		lwp_options => {},
		submit      => 0,
	};
	foreach my $p (@_) {
		$ret->{ $p->[0] } = $p->[1];
	}
	return $ret;
}

sub efa_new {
	return new_ok( 'Travel::Routing::DE::VRR' => [ %{ efa_conf(@_) } ] );
}

sub is_efa_post {
	my ( $ck, $cv, @post ) = @_;
	my $efa = efa_new( [ $ck, $cv ] );

	my $ok = 1;

	is_deeply(
		$efa->{'config'},
		efa_conf( [ $ck, $cv ] ),
		"$ck => $cv: conf ok",
	);

	foreach my $ref (@post) {
		my ( $key, $value ) = @{$ref};
		if (    not defined $efa->{'post'}->{"key"}
			and not defined $value )
		{
			next;
		}
		if ( $efa->{'post'}->{"$key"} ne $value ) {
			$ok = 0;
			last;
		}
	}
	ok( $ok, "$ck => $cv: POST okay", );
}

sub is_efa_err {
	my ( $ck, $cv, $exception ) = @_;

	isa_ok(
		exception {
			Travel::Routing::DE::VRR->new( %{ efa_conf( [ $ck, $cv ] ) } )
		},
		$exception,
		"$ck => $cv"
	);
}

is_efa_post( 'ignored', 'ignored' );

my $efa;

is_efa_post(
	'via',
	[ 'MH',        'HBf' ],
	[ 'place_via', 'MH' ],
	[ 'name_via',  'HBf' ],
	[ 'type_via',  'stop' ],
);

is_efa_post(
	'origin',
	[ 'D',            'Fuerstenwall 232', 'address' ],
	[ 'place_origin', 'D' ],
	[ 'name_origin',  'Fuerstenwall 232' ],
	[ 'type_origin',  'address' ],
);

is_efa_post(
	'departure_time', '22:23',
	[ 'itdTripDateTimeDepArr', 'dep' ],
	[ 'itdTimeHour',           '22' ],
	[ 'itdTimeMinute',         '23' ],
);

is_efa_post(
	'arrival_time', '16:38',
	[ 'itdTripDateTimeDepArr', 'arr' ],
	[ 'itdTimeHour',           '16' ],
	[ 'itdTimeMinute',         '38' ],
);

is_efa_post(
	'date', '2.10.2009',
	[ 'itdDateDay',   '2' ],
	[ 'itdDateMonth', '10' ],
	[ 'itdDateYear',  '2009' ],
);

is_efa_post(
	'date', '26.12.',
	[ 'itdDateDay',   '26' ],
	[ 'itdDateMonth', '12' ],
	[ 'itdDateYear', ( localtime(time) )[5] + 1900 ],
);

is_efa_post( 'exclude', [qw[zug]], [ 'inclMOT_0', undef ], );

is_efa_post(
	'exclude', [qw[stadtbus schiff ast]],
	[ 'inclMOT_5',  undef ],
	[ 'inclMOT_9',  undef ],
	[ 'inclMOT_10', undef ],
);

is_efa_post( 'select_interchange_by', 'speed', [ 'routeType', 'LEASTTIME' ], );

is_efa_post( 'select_interchange_by', 'waittime',
	[ 'routeType', 'LEASTINTERCHANGE' ],
);

is_efa_post( 'select_interchange_by', 'distance',
	[ 'routeType', 'LEASTWALKING' ],
);

is_efa_post( 'train_type', 'local', [ 'lineRestriction', 403 ], );

is_efa_post( 'train_type', 'ic', [ 'lineRestriction', 401 ], );

is_efa_post( 'train_type', 'ice', [ 'lineRestriction', 400 ], );

is_efa_post( 'walk_speed', 'normal', [ 'changeSpeed', 'normal' ], );

is_efa_post( 'max_interchanges', 5, [ 'maxChanges', 5 ], );

is_efa_post( 'use_near_stops', 1, [ 'useProxFootSearch', 1 ], );

is_efa_post( 'with_bike', 1, [ 'bikeTakeAlong', 1 ], );

is_efa_err( 'departure_time', '37:00',
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'departure_time', '07',
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'train_type', 'invalid',
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'walk_speed', 'invalid',
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'select_interchange_by', 'invalid',
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'exclude', [qw[sonstige invalid]],
	'Travel::Routing::DE::EFA::Exception::Setup',
);

is_efa_err( 'date', '42.5.2003',
	'Travel::Routing::DE::EFA::Exception::Setup', );

is_efa_err( 'date', '7.', 'Travel::Routing::DE::EFA::Exception::Setup', );
