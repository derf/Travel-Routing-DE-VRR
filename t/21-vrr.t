#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use utf8;

use File::Slurp qw(slurp);
use Test::More tests => 82;

BEGIN {
	use_ok('Travel::Routing::DE::EFA');
}
require_ok('Travel::Routing::DE::EFA');

my $xml = slurp('t/in/e_alf_d_hbf.xml');

my $routing = Travel::Routing::DE::EFA->new_from_xml( efa_url => 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2', xml => $xml );

isa_ok( $routing, 'Travel::Routing::DE::EFA' );
can_ok( $routing, 'routes' );

for my $r ( $routing->routes ) {
	isa_ok( $r, 'Travel::Routing::DE::EFA::Route' );
	can_ok( $r,
		qw(duration parts ticket_type fare_adult fare_child vehicle_time) );

	for my $c ( $r->parts ) {
		isa_ok( $c, 'Travel::Routing::DE::EFA::Route::Part' );
		can_ok(
			$c, qw(
			  arrival_stop arrival_platform arrival_stop_and_platform
			  arrival_date arrival_sdate arrival_time arrival_stime
			  departure_stop departure_platform departure_stop_and_platform
			  departure_date departure_sdate departure_time departure_stime
			  delay extra train_line train_destination
			  )
		);
	}
}

my $r0 = ( $routing->routes )[0];

is( $r0->duration,     '00:45', 'r0: duration' );
is( $r0->vehicle_time, 35,      'r0: vehicle_time' );
is( $r0->ticket_type,  'B',     'r0: ticket_type' );
is( $r0->fare_adult,   '4.70',  'r0: fare_adult' );
is( $r0->fare_child,   '1.40',  'r0: fare_child' );

my ( $c0, $c1 ) = $r0->parts;

is( $c0->delay, 0, 'r0,0: delay' );
is_deeply( [ $c0->extra ], [], 'r0,0: extra' );
is_deeply( [ $c0->departure_routemaps ], ['http://efa.vrr.de/vrr/FILELOAD?Filename=dwa_4ED23486C.pdf'], 'r0,0: departure_routemaps');
is_deeply( [ $c0->departure_stationmaps ], [], 'r0,0: departure_stationmaps');
is_deeply( [ $c0->arrival_routemaps ], ['http://efa.vrr.de/vrr/FILELOAD?Filename=dwa_4ED23486D.pdf'], 'r0,0: arrival_routemaps');
is_deeply( [ $c0->arrival_stationmaps ], ['http://efa.vrr.de/download/envmaps/vrr/09289_e_hbf_1.htm'], 'r0,0: arrival_stationmaps');
is( $c0->train_line, 'Straßenbahn 107', 'r0,0: line' );
is( $c0->train_destination,  'Essen Hanielstr. Schleife', 'r0,0: dest' );
is( $c0->departure_stop,     'Essen Alfredusbad',         'r0,0: dstop' );
is( $c0->departure_platform, 'Bstg. 1',                   'r0,0: dplatf' );
is(
	$c0->departure_stop_and_platform,
	'Essen Alfredusbad: Bstg. 1',
	'r0,0: dsp'
);
is( $c0->departure_date,   '27.11.2011',         'r0,0: drdate' );
is( $c0->departure_sdate,  '27.11.2011',         'r0,0: dsdate' );
is( $c0->departure_time,   '13:55',              'r0,0: drtime' );
is( $c0->departure_stime,  '13:55',              'r0,0: dstime' );
is( $c0->arrival_stop,     'Essen Hauptbahnhof', 'r0,0: astop' );
is( $c0->arrival_platform, 'Bstg. 1',            'r0,0: aplatf' );
is( $c0->arrival_stop_and_platform, 'Essen Hauptbahnhof: Bstg. 1',
	'r0,0: asp' );
is( $c0->arrival_date,  '27.11.2011', 'r0,0: ardate' );
is( $c0->arrival_sdate, '27.11.2011', 'r0,0: asdate' );
is( $c0->arrival_time,  '14:02',      'r0,0: artime' );
is( $c0->arrival_stime, '14:02',      'r0,0: astime' );

is_deeply( ($c0->via)[0],
	['27.11.2011', '13:56', 'Essen Florastr.', 'Bstg. 1', undef],
	'r0,0: via[0]');

is( $c1->delay, 3, 'r0,1: delay' );
is_deeply(
	[ $c1->extra ],
	[ 'Fahrradmitnahme begrenzt möglich' ],
	'r0,1: extra'
);
is_deeply( [ $c1->departure_routemaps ], ['http://efa.vrr.de/vrr/FILELOAD?Filename=dwa_4ED23486D.pdf'], 'r0,0: departure_routemaps');
is_deeply( [ $c1->departure_stationmaps ], ['http://efa.vrr.de/download/envmaps/vrr/09289_e_hbf_1.htm'], 'r0,0: departure_stationmaps');
is_deeply( [ $c1->arrival_routemaps ], ['http://efa.vrr.de/vrr/FILELOAD?Filename=dwa_4ED23486E.pdf'], 'r0,0: arrival_routemaps');
is_deeply( [ $c1->arrival_stationmaps ], ['http://efa.vrr.de/download/envmaps/vrr/18235_d_hbf_1.htm'], 'r0,0: arrival_stationmaps');
is( $c1->train_line,         'R-Bahn RE1',         'r0,1: line' );
is( $c1->train_destination,  'Aachen, Hbf',        'r0,1: dest' );
is( $c1->departure_stop,     'Essen Hauptbahnhof', 'r0,1: dstop' );
is( $c1->departure_platform, 'Gleis 2',            'r0,1: dplatf' );
is(
	$c1->departure_stop_and_platform,
	'Essen Hauptbahnhof: Gleis 2',
	'r0,1: dsp'
);
is( $c1->departure_date,  '27.11.2011', 'r0,1: drdate' );
is( $c1->departure_sdate, '27.11.2011', 'r0,1: dsdate' );
is( $c1->departure_time,  '14:12',      'r0,1: drtime' );
is( $c1->departure_stime, '14:09',      'r0,1: dstime' );
is( $c1->arrival_stop, 'Düsseldorf Hbf', 'r0,1: astop' );
is( $c1->arrival_platform, 'Gleis 16', 'r0,1: aplatf' );
is(
	$c1->arrival_stop_and_platform,
	'Düsseldorf Hbf: Gleis 16',
	'r0,1: asp'
);
is( $c1->arrival_date,  '27.11.2011', 'r0,1: ardate' );
is( $c1->arrival_sdate, '27.11.2011', 'r0,1: asdate' );
is( $c1->arrival_time,  '14:40',      'r0,1: artime' );
is( $c1->arrival_stime, '14:37',      'r0,1: astime' );
