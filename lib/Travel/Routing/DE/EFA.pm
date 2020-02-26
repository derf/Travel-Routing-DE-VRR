package Travel::Routing::DE::EFA;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => "experimental::smartmatch";

use Carp qw(cluck);
use Encode qw(encode);
use Travel::Routing::DE::EFA::Route;
use Travel::Routing::DE::EFA::Route::Message;
use LWP::UserAgent;
use XML::LibXML;

use Exception::Class (
	'Travel::Routing::DE::EFA::Exception',
	'Travel::Routing::DE::EFA::Exception::Setup' => {
		isa         => 'Travel::Routing::DE::EFA::Exception',
		description => 'invalid argument on setup',
		fields      => [ 'option', 'have', 'want' ],
	},
	'Travel::Routing::DE::EFA::Exception::Net' => {
		isa         => 'Travel::Routing::DE::EFA::Exception',
		description => 'could not submit POST request',
		fields      => 'http_response',
	},
	'Travel::Routing::DE::EFA::Exception::NoData' => {
		isa         => 'Travel::Routing::DE::EFA::Exception',
		description => 'backend returned no parsable route',
	},
	'Travel::Routing::DE::EFA::Exception::Ambiguous' => {
		isa         => 'Travel::Routing::DE::EFA::Exception',
		description => 'ambiguous input',
		fields      => [ 'post_key', 'post_value', 'possibilities' ],
	},
	'Travel::Routing::DE::EFA::Exception::Other' => {
		isa         => 'Travel::Routing::DE::EFA::Exception',
		description => 'EFA backend returned an error',
		fields      => ['message'],
	},
);

our $VERSION = '2.18';

sub set_time {
	my ( $self, %conf ) = @_;

	my $time;

	if ( $conf{departure_time} ) {
		$self->{post}->{itdTripDateTimeDepArr} = 'dep';
		$time = $conf{departure_time};
	}
	elsif ( $conf{arrival_time} ) {
		$self->{post}->{itdTripDateTimeDepArr} = 'arr';
		$time = $conf{arrival_time};
	}
	else {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'time',
			error  => 'Specify either departure_time or arrival_time'
		);
	}

	if ( $time !~ / ^ [0-2]? \d : [0-5]? \d $ /x ) {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'time',
			have   => $time,
			want   => 'HH:MM',
		);
	}

	@{ $self->{post} }{ 'itdTimeHour', 'itdTimeMinute' } = split( /:/, $time );

	return;
}

sub departure_time {
	my ( $self, $time ) = @_;

	return $self->set_time( departure_time => $time );
}

sub arrival_time {
	my ( $self, $time ) = @_;

	return $self->set_time( arrival_time => $time );
}

sub date {
	my ( $self, $date ) = @_;

	my ( $day, $month, $year ) = split( /[.]/, $date );

	if ( $date eq 'tomorrow' ) {
		( undef, undef, undef, $day, $month, $year )
		  = localtime( time + 86400 );
		$month += 1;
		$year  += 1900;
	}

	if (
		not(    defined $day
			and length($day)
			and $day >= 1
			and $day <= 31
			and defined $month
			and length($month)
			and $month >= 1
			and $month <= 12 )
	  )
	{
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'date',
			have   => $date,
			want   => 'DD.MM[.[YYYY]]'
		);
	}

	if ( not defined $year or not length($year) ) {
		$year = ( localtime(time) )[5] + 1900;
	}

	@{ $self->{post} }{ 'itdDateDay', 'itdDateMonth', 'itdDateYear' }
	  = ( $day, $month, $year );

	return;
}

sub exclude {
	my ( $self, @exclude ) = @_;

	my @mapping = qw{
	  zug s-bahn u-bahn stadtbahn tram stadtbus regionalbus
	  schnellbus seilbahn schiff ast sonstige
	};

	foreach my $exclude_type (@exclude) {
		my $ok = 0;
		for my $map_id ( 0 .. $#mapping ) {
			if ( $exclude_type eq $mapping[$map_id] ) {
				delete $self->{post}->{"inclMOT_${map_id}"};
				$ok = 1;
			}
		}
		if ( not $ok ) {
			Travel::Routing::DE::EFA::Exception::Setup->throw(
				option => 'exclude',
				have   => $exclude_type,
				want   => join( ' / ', @mapping ),
			);
		}
	}

	return;
}

sub max_interchanges {
	my ( $self, $max ) = @_;

	$self->{post}->{maxChanges} = $max;

	return;
}

sub number_of_trips {
	my ( $self, $num ) = @_;

	$self->{post}->{calcNumberOfTrips} = $num;

	return;
}

sub select_interchange_by {
	my ( $self, $prefer ) = @_;

	given ($prefer) {
		when ('speed')    { $self->{post}->{routeType} = 'LEASTTIME' }
		when ('waittime') { $self->{post}->{routeType} = 'LEASTINTERCHANGE' }
		when ('distance') { $self->{post}->{routeType} = 'LEASTWALKING' }
		default {
			Travel::Routing::DE::EFA::Exception::Setup->throw(
				option => 'select_interchange_by',
				have   => $prefer,
				want   => 'speed / waittime / distance',
			);
		}
	}

	return;
}

sub train_type {
	my ( $self, $include ) = @_;

	given ($include) {
		when ('local') { $self->{post}->{lineRestriction} = 403 }
		when ('ic')    { $self->{post}->{lineRestriction} = 401 }
		when ('ice')   { $self->{post}->{lineRestriction} = 400 }
		default {
			Travel::Routing::DE::EFA::Exception::Setup->throw(
				option => 'train_type',
				have   => $include,
				want   => 'local / ic / ice',
			);
		}
	}

	return;
}

sub use_near_stops {
	my ( $self, $duration ) = @_;

	if ($duration) {
		$self->{post}->{useProxFootSearch}  = 1;
		$self->{post}->{trITArrMOTvalue100} = $duration;
		$self->{post}->{trITDepMOTvalue100} = $duration;
	}
	else {
		$self->{post}->{useProxFootSearch} = 0;
	}

	return;
}

sub walk_speed {
	my ( $self, $walk_speed ) = @_;

	if ( $walk_speed ~~ [ 'normal', 'fast', 'slow' ] ) {
		$self->{post}->{changeSpeed} = $walk_speed;
	}
	else {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'walk_speed',
			have   => $walk_speed,
			want   => 'normal / fast / slow',
		);
	}

	return;
}

sub with_bike {
	my ( $self, $bike ) = @_;

	$self->{post}->{bikeTakeAlong} = $bike;

	return;
}

sub without_solid_stairs {
	my ( $self, $opt ) = @_;

	$self->{post}->{noSolidStairs} = $opt;

	return;
}

sub without_escalators {
	my ( $self, $opt ) = @_;

	$self->{post}->{noEscalators} = $opt;

	return;
}

sub without_elevators {
	my ( $self, $opt ) = @_;

	$self->{post}->{noElevators} = $opt;

	return;
}

sub with_low_platform {
	my ( $self, $opt ) = @_;

	$self->{post}->{lowPlatformVhcl} = $opt;

	return;
}

sub with_wheelchair {
	my ( $self, $opt ) = @_;

	$self->{post}->{wheelchair} = $opt;

	return;
}

sub place {
	my ( $self, $which, $place, $stop, $type ) = @_;

	if ( not( $place and $stop ) ) {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'place',
			error  => 'Need >= three elements'
		);
	}

	$type //= 'stop';

	@{ $self->{post} }{ "place_${which}", "name_${which}" } = ( $place, $stop );

	if ( $type ~~ [qw[address poi stop]] ) {
		$self->{post}->{"type_${which}"} = $type;
	}

	return;
}

sub create_post {
	my ($self) = @_;

	my $conf = $self->{config};
	my @now  = localtime( time() );

	$self->{post} = {
		changeSpeed            => 'normal',
		command                => q{},
		execInst               => q{},
		imparedOptionsActive   => 1,
		inclMOT_0              => 'on',
		inclMOT_1              => 'on',
		inclMOT_10             => 'on',
		inclMOT_11             => 'on',
		inclMOT_2              => 'on',
		inclMOT_3              => 'on',
		inclMOT_4              => 'on',
		inclMOT_5              => 'on',
		inclMOT_6              => 'on',
		inclMOT_7              => 'on',
		inclMOT_8              => 'on',
		inclMOT_9              => 'on',
		includedMeans          => 'checkbox',
		itOptionsActive        => 1,
		itdDateDay             => $now[3],
		itdDateMonth           => $now[4] + 1,
		itdDateYear            => $now[5] + 1900,
		itdTimeHour            => $now[2],
		itdTimeMinute          => $now[1],
		itdTripDateTimeDepArr  => 'dep',
		language               => 'de',
		lineRestriction        => 403,
		maxChanges             => 9,
		nameInfo_destination   => 'invalid',
		nameInfo_origin        => 'invalid',
		nameInfo_via           => 'invalid',
		nameState_destination  => 'empty',
		nameState_origin       => 'empty',
		nameState_via          => 'empty',
		name_destination       => q{},
		name_origin            => q{},
		name_via               => q{},
		nextDepsPerLeg         => 1,
		outputFormat           => 'XML',
		placeInfo_destination  => 'invalid',
		placeInfo_origin       => 'invalid',
		placeInfo_via          => 'invalid',
		placeState_destination => 'empty',
		placeState_origin      => 'empty',
		placeState_via         => 'empty',
		place_destination      => q{},
		place_origin           => q{},
		place_via              => q{},
		ptOptionsActive        => 1,
		requestID              => 0,
		routeType              => 'LEASTTIME',
		sessionID              => 0,
		text                   => 1993,
		trITArrMOT             => 100,
		trITArrMOTvalue100     => 10,
		trITArrMOTvalue101     => 10,
		trITArrMOTvalue104     => 10,
		trITArrMOTvalue105     => 10,
		trITDepMOT             => 100,
		trITDepMOTvalue100     => 10,
		trITDepMOTvalue101     => 10,
		trITDepMOTvalue104     => 10,
		trITDepMOTvalue105     => 10,
		typeInfo_destination   => 'invalid',
		typeInfo_origin        => 'invalid',
		typeInfo_via           => 'invalid',
		type_destination       => 'stop',
		type_origin            => 'stop',
		type_via               => 'stop',
		useRealtime            => 1
	};

	$self->place( 'origin',      @{ $conf->{origin} } );
	$self->place( 'destination', @{ $conf->{destination} } );

	if ( $conf->{via} ) {
		$self->place( 'via', @{ $conf->{via} } );
	}
	if ( $conf->{arrival_time} || $conf->{departure_time} ) {
		$self->set_time( %{$conf} );
	}
	if ( $conf->{date} ) {
		$self->date( $conf->{date} );
	}
	if ( $conf->{exclude} ) {
		$self->exclude( @{ $conf->{exclude} } );
	}
	if ( $conf->{max_interchanges} ) {
		$self->max_interchanges( $conf->{max_interchanges} );
	}
	if ( $conf->{num_results} ) {
		$self->number_of_trips( $conf->{num_results} );
	}
	if ( $conf->{select_interchange_by} ) {
		$self->select_interchange_by( $conf->{select_interchange_by} );
	}
	if ( $conf->{use_near_stops} ) {
		$self->use_near_stops( $conf->{use_near_stops} );
	}
	if ( $conf->{train_type} ) {
		$self->train_type( $conf->{train_type} );
	}
	if ( $conf->{walk_speed} ) {
		$self->walk_speed( $conf->{walk_speed} );
	}
	if ( $conf->{with_bike} ) {
		$self->with_bike(1);
	}
	if ( $conf->{with_low_platform} ) {
		$self->with_low_platform(1);
	}
	if ( $conf->{with_wheelchair} ) {
		$self->with_wheelchair(1);
	}
	if ( $conf->{without_solid_stairs} ) {
		$self->without_solid_stairs(1);
	}
	if ( $conf->{without_escalators} ) {
		$self->without_escalators(1);
	}
	if ( $conf->{without_elevators} ) {
		$self->without_elevators(1);
	}

	for my $val ( values %{ $self->{post} } ) {
		$val = encode( 'UTF-8', $val );
	}

	return;
}

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = {};

	$ref->{config} = \%conf;

	bless( $ref, $obj );

	if ( not $ref->{config}->{efa_url} ) {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'efa_url',
			error  => 'must be set'
		);
	}

	$ref->{config}->{efa_url} =~ m{
		(?<netroot> (?<root> [^:]+ : // [^/]+ ) / [^/]+ / )
	}ox;

	$ref->{config}->{rm_base} = $+{netroot};
	$ref->{config}->{sm_base} = $+{root} . '/download/envmaps/';

	$ref->create_post;

	if ( not( defined $conf{submit} and $conf{submit} == 0 ) ) {
		$ref->submit( %{ $conf{lwp_options} } );
	}

	return $ref;
}

sub new_from_xml {
	my ( $class, %opt ) = @_;

	my $self = { xml_reply => $opt{xml} };

	$self->{config} = {
		efa_url => $opt{efa_url},
	};

	$self->{config}->{efa_url} =~ m{
		(?<netroot> (?<root> [^:]+ : // [^/]+ ) / [^/]+ / )
	}ox;

	$self->{config}->{rm_base} = $+{netroot};
	$self->{config}->{sm_base} = $+{root} . '/download/envmaps/';

	bless( $self, $class );

	$self->parse_xml;

	return $self;
}

sub submit {
	my ( $self, %conf ) = @_;

	$self->{ua} = LWP::UserAgent->new(%conf);
	$self->{ua}->env_proxy;

	my $response
	  = $self->{ua}->post( $self->{config}->{efa_url}, $self->{post} );

	if ( $response->is_error ) {
		Travel::Routing::DE::EFA::Exception::Net->throw(
			http_response => $response,
		);
	}

	$self->{xml_reply} = $response->decoded_content;

	$self->parse_xml;

	return;
}

sub itddate_str {
	my ( $self, $node ) = @_;

	return sprintf( '%02d.%02d.%04d',
		$node->getAttribute('day'),
		$node->getAttribute('month'),
		$node->getAttribute('year') );
}

sub itdtime_str {
	my ( $self, $node ) = @_;

	return sprintf( '%02d:%02d',
		$node->getAttribute('hour'),
		$node->getAttribute('minute') );
}

sub parse_cur_info {
	my ( $self, $node ) = @_;

	my $xp_text     = XML::LibXML::XPathExpression->new('./infoLinkText');
	my $xp_subject  = XML::LibXML::XPathExpression->new('./infoText/subject');
	my $xp_subtitle = XML::LibXML::XPathExpression->new('./infoText/subtitle');
	my $xp_content  = XML::LibXML::XPathExpression->new('./infoText/content');

	my $e_text     = ( $node->findnodes($xp_text) )[0];
	my $e_subject  = ( $node->findnodes($xp_subject) )[0];
	my $e_subtitle = ( $node->findnodes($xp_subtitle) )[0];
	my $e_content  = ( $node->findnodes($xp_content) )[0];

	my %msg = (
		summary     => $e_text->textContent,
		subject     => $e_subject->textContent,
		subtitle    => $e_subtitle->textContent,
		raw_content => $e_content->textContent,
	);
	for my $key ( keys %msg ) {
		chomp( $msg{$key} );
	}
	return Travel::Routing::DE::EFA::Route::Message->new(%msg);
}

sub parse_reg_info {
	my ( $self, $node ) = @_;

	my %msg = (
		summary => $node->textContent,
	);

	return Travel::Routing::DE::EFA::Route::Message->new(%msg);
}

sub parse_xml_part {
	my ( $self, $route ) = @_;

	my $xp_route = XML::LibXML::XPathExpression->new(
		'./itdPartialRouteList/itdPartialRoute');
	my $xp_dep
	  = XML::LibXML::XPathExpression->new('./itdPoint[@usage="departure"]');
	my $xp_arr
	  = XML::LibXML::XPathExpression->new('./itdPoint[@usage="arrival"]');
	my $xp_date = XML::LibXML::XPathExpression->new('./itdDateTime/itdDate');
	my $xp_time = XML::LibXML::XPathExpression->new('./itdDateTime/itdTime');
	my $xp_via  = XML::LibXML::XPathExpression->new('./itdStopSeq/itdPoint');

	my $xp_sdate
	  = XML::LibXML::XPathExpression->new('./itdDateTimeTarget/itdDate');
	my $xp_stime
	  = XML::LibXML::XPathExpression->new('./itdDateTimeTarget/itdTime');
	my $xp_mot = XML::LibXML::XPathExpression->new('./itdMeansOfTransport');
	my $xp_fp  = XML::LibXML::XPathExpression->new('./itdFootPathInfo');
	my $xp_fp_e
	  = XML::LibXML::XPathExpression->new('./itdFootPathInfo/itdFootPathElem');
	my $xp_delay = XML::LibXML::XPathExpression->new('./itdRBLControlled');

	my $xp_sched_info
	  = XML::LibXML::XPathExpression->new('./itdInfoTextList/infoTextListElem');
	my $xp_cur_info = XML::LibXML::XPathExpression->new('./infoLink');

	my $xp_mapitem_rm = XML::LibXML::XPathExpression->new(
		'./itdMapItemList/itdMapItem[@type="RM"]/itdImage');
	my $xp_mapitem_sm = XML::LibXML::XPathExpression->new(
		'./itdMapItemList/itdMapItem[@type="SM"]/itdImage');

	my $xp_fare
	  = XML::LibXML::XPathExpression->new('./itdFare/itdSingleTicket');

	my @route_parts;

	my $info = {
		duration     => $route->getAttribute('publicDuration'),
		vehicle_time => $route->getAttribute('vehicleTime'),
	};

	my $e_fare = ( $route->findnodes($xp_fare) )[0];

	if ($e_fare) {
		$info->{ticket_type} = $e_fare->getAttribute('unitsAdult');
		$info->{fare_adult}  = $e_fare->getAttribute('fareAdult');
		$info->{fare_child}  = $e_fare->getAttribute('fareChild');
		$info->{ticket_text} = $e_fare->textContent;
	}

	for my $e ( $route->findnodes($xp_route) ) {

		my $e_dep     = ( $e->findnodes($xp_dep) )[0];
		my $e_arr     = ( $e->findnodes($xp_arr) )[0];
		my $e_ddate   = ( $e_dep->findnodes($xp_date) )[0];
		my $e_dtime   = ( $e_dep->findnodes($xp_time) )[0];
		my $e_dsdate  = ( $e_dep->findnodes($xp_sdate) )[0];
		my $e_dstime  = ( $e_dep->findnodes($xp_stime) )[0];
		my $e_adate   = ( $e_arr->findnodes($xp_date) )[0];
		my $e_atime   = ( $e_arr->findnodes($xp_time) )[0];
		my $e_asdate  = ( $e_arr->findnodes($xp_sdate) )[0];
		my $e_astime  = ( $e_arr->findnodes($xp_stime) )[0];
		my $e_mot     = ( $e->findnodes($xp_mot) )[0];
		my $e_delay   = ( $e->findnodes($xp_delay) )[0];
		my $e_fp      = ( $e->findnodes($xp_fp) )[0];
		my @e_sinfo   = $e->findnodes($xp_sched_info);
		my @e_cinfo   = $e->findnodes($xp_cur_info);
		my @e_dmap_rm = $e_dep->findnodes($xp_mapitem_rm);
		my @e_dmap_sm = $e_dep->findnodes($xp_mapitem_sm);
		my @e_amap_rm = $e_arr->findnodes($xp_mapitem_rm);
		my @e_amap_sm = $e_arr->findnodes($xp_mapitem_sm);
		my @e_fp_e    = $e->findnodes($xp_fp_e);

		# not all EFA services distinguish between scheduled and realtime
		# data. Set sdate / stime to date / time when not provided.
		$e_dsdate //= $e_ddate;
		$e_dstime //= $e_dtime;
		$e_asdate //= $e_adate;
		$e_astime //= $e_atime;

		my $delay = $e_delay ? $e_delay->getAttribute('delayMinutes') : 0;

		my ( @dep_rms, @dep_sms, @arr_rms, @arr_sms );

		if ( $self->{config}->{rm_base} ) {
			my $base = $self->{config}->{rm_base};
			@dep_rms = map { $base . $_->getAttribute('src') } @e_dmap_rm;
			@arr_rms = map { $base . $_->getAttribute('src') } @e_amap_rm;
		}
		if ( $self->{config}->{sm_base} ) {
			my $base = $self->{config}->{sm_base};
			@dep_sms = map { $base . $_->getAttribute('src') } @e_dmap_sm;
			@arr_sms = map { $base . $_->getAttribute('src') } @e_amap_sm;
		}

		my $hash = {
			delay              => $delay,
			departure_date     => $self->itddate_str($e_ddate),
			departure_time     => $self->itdtime_str($e_dtime),
			departure_sdate    => $self->itddate_str($e_dsdate),
			departure_stime    => $self->itdtime_str($e_dstime),
			departure_stop     => $e_dep->getAttribute('name'),
			departure_platform => $e_dep->getAttribute('platformName'),
			train_line         => $e_mot->getAttribute('name'),
			train_product      => $e_mot->getAttribute('productName'),
			train_destination  => $e_mot->getAttribute('destination'),
			arrival_date       => $self->itddate_str($e_adate),
			arrival_time       => $self->itdtime_str($e_atime),
			arrival_sdate      => $self->itddate_str($e_asdate),
			arrival_stime      => $self->itdtime_str($e_astime),
			arrival_stop       => $e_arr->getAttribute('name'),
			arrival_platform   => $e_arr->getAttribute('platformName'),
		};

		if ($e_fp) {

			# Note that position=IDEST footpaths are coupled with a special
			# "walking" connection, so their duration is already known and
			# accounted for. However, we still save it here, since
			# detecting and handling this is the API client's job (for now).
			$hash->{footpath_type}     = $e_fp->getAttribute('position');
			$hash->{footpath_duration} = $e_fp->getAttribute('duration');
			for my $e (@e_fp_e) {
				push(
					@{ $hash->{footpath_parts} },
					[ $e->getAttribute('type'), $e->getAttribute('level') ]
				);
			}
		}

		$hash->{departure_routemaps}   = \@dep_rms;
		$hash->{departure_stationmaps} = \@dep_sms;
		$hash->{arrival_routemaps}     = \@arr_rms;
		$hash->{arrival_stationmaps}   = \@arr_sms;

		for my $ve ( $e->findnodes($xp_via) ) {
			my $e_vdate = ( $ve->findnodes($xp_date) )[-1];
			my $e_vtime = ( $ve->findnodes($xp_time) )[-1];

			if ( not( $e_vdate and $e_vtime )
				or ( $e_vdate->getAttribute('weekday') == -1 ) )
			{
				next;
			}

			my $name     = $ve->getAttribute('name');
			my $platform = $ve->getAttribute('platformName');

			if ( $name ~~ [ $hash->{departure_stop}, $hash->{arrival_stop} ] ) {
				next;
			}

			push(
				@{ $hash->{via} },
				[
					$self->itddate_str($e_vdate),
					$self->itdtime_str($e_vtime),
					$name,
					$platform
				]
			);
		}

		$hash->{regular_notes}
		  = [ map { $self->parse_reg_info($_) } @e_sinfo ];
		$hash->{current_notes} = [ map { $self->parse_cur_info($_) } @e_cinfo ];

		push( @route_parts, $hash );
	}

	push(
		@{ $self->{routes} },
		Travel::Routing::DE::EFA::Route->new( $info, @route_parts )
	);

	return;
}

sub parse_xml {
	my ($self) = @_;

	my $tree = $self->{tree} = XML::LibXML->load_xml(
		string => $self->{xml_reply},
	);

	if ( $self->{config}->{developer_mode} ) {
		say $tree->toString(2);
	}

	my $xp_element = XML::LibXML::XPathExpression->new(
		'//itdItinerary/itdRouteList/itdRoute');
	my $xp_err = XML::LibXML::XPathExpression->new(
		'//itdTripRequest/itdMessage[@type="error"]');
	my $xp_odv = XML::LibXML::XPathExpression->new('//itdOdv');

	for my $odv ( $tree->findnodes($xp_odv) ) {
		$self->check_ambiguous_xml($odv);
	}

	my $err = ( $tree->findnodes($xp_err) )[0];
	if ($err) {
		Travel::Routing::DE::EFA::Exception::Other->throw(
			message => $err->textContent );
	}

	for my $part ( $tree->findnodes($xp_element) ) {
		$self->parse_xml_part($part);
	}

	if ( not defined $self->{routes} or @{ $self->{routes} } == 0 ) {
		Travel::Routing::DE::EFA::Exception::NoData->throw;
	}

	return 1;
}

sub check_ambiguous_xml {
	my ( $self, $tree ) = @_;

	my $xp_place = XML::LibXML::XPathExpression->new('./itdOdvPlace');
	my $xp_name  = XML::LibXML::XPathExpression->new('./itdOdvName');

	my $xp_place_elem  = XML::LibXML::XPathExpression->new('./odvPlaceElem');
	my $xp_place_input = XML::LibXML::XPathExpression->new('./odvPlaceInput');
	my $xp_name_elem   = XML::LibXML::XPathExpression->new('./odvNameElem');
	my $xp_name_input  = XML::LibXML::XPathExpression->new('./odvNameInput');

	my $e_place = ( $tree->findnodes($xp_place) )[0];
	my $e_name  = ( $tree->findnodes($xp_name) )[0];

	if ( not( $e_place and $e_name ) ) {
		cluck('skipping ambiguity check - itdOdvPlace/itdOdvName missing');
		return;
	}

	my $s_place = $e_place->getAttribute('state');
	my $s_name  = $e_name->getAttribute('state');

	if ( $s_place eq 'list' ) {
		Travel::Routing::DE::EFA::Exception::Ambiguous->throw(
			post_key => 'place',
			post_value =>
			  ( $e_place->findnodes($xp_place_input) )[0]->textContent,
			possibilities => join( q{ | },
				map { $_->textContent }
				  @{ $e_place->findnodes($xp_place_elem) } )
		);
	}
	if ( $s_name eq 'list' ) {
		Travel::Routing::DE::EFA::Exception::Ambiguous->throw(
			post_key => 'name',
			post_value =>
			  ( $e_name->findnodes($xp_name_input) )[0]->textContent,
			possibilities => join( q{ | },
				map { $_->textContent } @{ $e_name->findnodes($xp_name_elem) } )
		);
	}

	if ( $s_place eq 'notidentified' ) {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'place',
			error  => 'unknown place',
			have   => ( $e_place->findnodes($xp_place_input) )[0]->textContent,
		);
	}
	if ( $s_name eq 'notidentified' ) {
		Travel::Routing::DE::EFA::Exception::Setup->throw(
			option => 'name',
			error  => 'unknown name',
			have   => ( $e_name->findnodes($xp_name_input) )[0]->textContent,
		);
	}

	# 'identified' and 'empty' are ok

	return;
}

sub routes {
	my ($self) = @_;

	return @{ $self->{routes} };
}

# static
sub get_efa_urls {
	return (
		{
			url       => 'http://www.ding.eu/ding3/XSLT_TRIP_REQUEST2',
			name      => 'Donau-Iller Nahverkehrsverbund',
			shortname => 'DING',
		},
		{
			url       => 'http://efa.ivb.at/ivb/XSLT_TRIP_REQUEST2',
			name      => 'Innsbrucker Verkehrsbetriebe',
			shortname => 'IVB',
		},
		{
			url       => 'http://efa.svv-info.at/sbs/XSLT_TRIP_REQUEST2',
			name      => 'Salzburger Verkehrsverbund',
			shortname => 'SVV',
		},
		{
			url       => 'http://efa.vor.at/wvb/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Ost-Region',
			shortname => 'VOR',
		},
		{
			url  => 'https://projekte.kvv-efa.de/sl3-alone/XSLT_TRIP_REQUEST2',
			name => 'Karlsruher Verkehrsverbund',
			shortname => 'KVV',
		},

		# Returns broken Unicode which makes Encode::decode die()
		#{
		#	url  => 'http://fahrplan.verbundlinie.at/stv/XSLT_TRIP_REQUEST2',
		#	name => 'Verkehrsverbund Steiermark',
		#	shortname => 'Verbundlinie',
		#},
		{
			url       => 'http://www.linzag.at/static/XSLT_TRIP_REQUEST2',
			name      => 'Linz AG',
			shortname => 'LinzAG',
		},
		{
			url       => 'http://212.114.197.7/vgnExt_oeffi/XML_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Grossraum Nuernberg',
			shortname => 'VGN',
		},
		{
			url       => 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Rhein-Ruhr',
			shortname => 'VRR',
		},
		{
			url       => 'http://app.vrr.de/vrrstd/XML_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Rhein-Ruhr (alternative)',
			shortname => 'VRR2',
		},
		{
			url       => 'http://www2.vvs.de/vvs/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Stuttgart',
			shortname => 'VVS',
		},
		{
			url => 'http://delfi1.vvo-online.de:8080/delfi3/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Oberelbe',
			shortname => 'VVO',
		},
		{
			url       => 'http://delfi.vrn.de/delfi/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Rhein-Neckar (DELFI)',
			shortname => 'VRNdelfi',
		},
		{
			url       => 'http://fahrplanauskunft.vrn.de/vrn/XML_TRIP_REQUEST2',
			name      => 'Verkehrsverbund Rhein-Neckar',
			shortname => 'VRN',
		},
		{
			url       => 'http://80.146.180.107/vmv/XSLT_TRIP_REQUEST2',
			name      => 'Verkehrsgesellschaft Mecklenburg-Vorpommern',
			shortname => 'VMV',
		},
		{
			url =>
			  'http://www.travelineeastmidlands.co.uk/em/XSLT_TRIP_REQUEST2',
			name      => 'Traveline East Midlands',
			shortname => 'TLEM',
		},
		{
			url       => 'http://mobil.vbl.ch/vblmobil/XML_TRIP_REQUEST2',
			name      => 'Verkehrsbetriebe Luzern',
			shortname => 'VBL',
		},
		{
			url       => 'http://bsvg.efa.de/bsvagstd/XML_TRIP_REQUEST2',
			name      => 'Braunschweiger Verkehrs-GmbH',
			shortname => 'BSVG',
		},
	);
}

1;

__END__

=head1 NAME

Travel::Routing::DE::EFA - unofficial interface to EFA-based itinerary services

=head1 SYNOPSIS

	use Travel::Routing::DE::EFA;

	my $efa = Travel::Routing::DE::EFA->new(
		efa_url     => 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2',
		origin      => [ 'Essen',    'HBf' ],
		destination => [ 'Duisburg', 'HBf' ],
	);

	for my $route ( $efa->routes ) {
		for my $part ( $route->parts ) {
			printf(
				"%s at %s -> %s at %s, via %s to %s\n",
				$part->departure_time, $part->departure_stop,
				$part->arrival_time,   $part->arrival_stop,
				$part->train_line,     $part->train_destination,
			);
		}
		print "\n";
	}

=head1 VERSION

version 2.18

=head1 DESCRIPTION

B<Travel::Routing::DE::EFA> is a client for EFA-based itinerary services.
You pass it the start/stop of your journey, maybe a time and a date and more
details, and it returns the up-to-date scheduled connections between those two
stops.

It uses B<LWP::UserAgent> and B<XML::LibXML> for this.

=head1 METHODS

=over

=item $efa = Travel::Routing::DE::EFA->new(I<%opts>)

Returns a new Travel::Routing::DE::EFA object and sets up its POST data via
%opts.

Valid hash keys and their values are:

=over

=item B<efa_url> => I<efa_url>

Mandatory.  Sets the entry point to the EFA itinerary service.
The following URLs (grouped by country) are known.  A service marked with [!]
is not completely supported yet and may not work at all.

=over

=item * Austria

=over

=item * L<http://efa.ivb.at/ivb/XSLT_TRIP_REQUEST2> (Innsbrucker Verkehrsbetriebe)

=item * L<http://efa.svv-info.at/sbs/XSLT_TRIP_REQUEST2> (Salzburger Verkehrsverbund)

=item * L<http://efa.vor.at/wvb/XSLT_TRIP_REQUEST2> (Verkehrsverbund Ost-Region)

=item * L<http://efaneu.vmobil.at/vvv/XSLT_TRIP_REQUEST2> (Vorarlberger Verkehrsverbund)

=item * L<http://www.linzag.at/static/XSLT_TRIP_REQUEST2> (Linz AG) B<[!]>

=item * The STV / Verkehrsverbund Steiermark is not supported since it returns
data with broken encoding

=back

=item * Germany

=over

=item * L<http://212.114.197.7/vgnExt_oeffi/XML_TRIP_REQUEST2> (Verkehrsverbund GroE<szlig>raum NE<uuml>rnberg)

=item * L<http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2> (Verkehrsverbund Rhein-Ruhr)

=item * L<http://app.vrr.de/standard/XML_TRIP_REQUEST2> (Verkehrsverbund Rhein-Ruhr with support for B<--full-route>)

=item * L<http://www2.vvs.de/vvs/XSLT_TRIP_REQUEST2> (Verkehrsverbund Stuttgart)

=back

=back

If you found a URL not listed here, please send it to
E<lt>derf@finalrewind.orgE<gt>.

=item B<origin> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Mandatory.  Sets the start of the journey.
I<type> is optional and may be one of B<stop> (default), B<address> (street
and house number) or B<poi> ("point of interest").

=item B<destination> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Mandatory.  Sets the end of the journey, see B<origin>.

=item B<via> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Optional.  Specifies an intermediate stop which the resulting itinerary must
contain.  See B<origin> for arguments.

=item B<arrival_time> => I<HH:MM>

Journey end time

=item B<departure_time> => I<HH:MM>

Journey start time.  Default: now

=item B<date> => I<DD.MM.>[I<YYYY>]

Journey date.  Also accepts the string B<tomorrow>.  Default: today

=item B<exclude> => \@exclude

Do not use certain transport types for itinerary.  Accepted arguments:
zug, s-bahn, u-bahn, stadtbahn, tram, stadtbus, regionalbus, schnellbus,
seilbahn, schiff, ast, sonstige

=item B<max_interchanges> => I<num>

Set maximum number of interchanges

=item B<num_results> => I<num>

Return up to I<num> connections.  If unset, the default of the respective
EFA server is used (usually 4 or 5).

=item B<select_interchange_by> => B<speed>|B<waittime>|B<distance>

Prefer either fast connections (default), connections with low wait time or
connections with little distance to walk

=item B<use_near_stops> => I<$int>

If I<$int> is a true value: Take stops close to the stop/start into account and
possibly use them instead. Up to I<$int> minutes of walking are considered
acceptable.

Otherwise: Do not take stops close to stop/start into account.

=item B<train_type> => B<local>|B<ic>|B<ice>

Include only local trains into itinerary (default), all but ICEs, or all.

The latter two are usually way more expensive for short routes.

=item B<walk_speed> => B<slow>|B<fast>|B<normal>

Set walk speed.  Default: B<normal>

=item B<with_bike> => B<0>|B<1>

If true: Request connections allowing passengers with bikes. Note that the
backed may return an empty result if no such connection exists or bike-support
simply isn't known.

=item B<with_low_platform> => B<0>|B<1>

If true: Request connections which only use low-platform ("Niederflur")
vehicles. Note that the backed will return an empty result if no such
connection exists.

=item B<with_wheelchair> => B<0>|B<1>

If true: Request connections which are wheelchair-accessible. Again, note that
the backend may return an empty result if no such connection exists or
wheelchair-support isn't known.

=item B<without_elevators> => B<0>|B<1>

If true: Request that transfers do not require usage of elevators.

=item B<without_escalators> => B<0>|B<1>

If true: Request that transfers do not require usage of escalators.

=item B<without_solid_stairs> => B<0>|B<1>

If true: Request that transfers do not require stairs to be taken (i.e.
ramps, escalators, elevators or similar must be available).

=item B<lwp_options> => I<\%hashref>

Options to pass to C<< LWP::UserAgent->new >>.

=item B<submit> => B<0>|B<1>

By default, B<new> will create a POST request and submit it.  If you do not
want it to be submitted yet, set this to B<0>.

=back

=item $efa->submit(I<%opts>)

Submit the query to I<efa_url>.
I<%opts> is passed on to C<< LWP::UserAgent->new >>.

=item $efa->routes

Returns a list of Travel::Routing::DE::EFA::Route(3pm) elements. Each one contains
one method of getting from start to stop.

=back

=head2 ACCESSORS

The following methods act like the arguments to B<new>. See there.

=over

=item $efa->departure_time(I<$time>)

=item $efa->arrival_time(I<$time>)

=item $efa->date(I<$date>)

=item $efa->exclude(I<@exclude>)

=item $efa->max_interchanges(I<$num>)

=item $efa->select_interchange_by(I<$selection>)

=item $efa->train_type(I<$type>)

=item $efa->use_near_stops(I<$duration>)

=item $efa->walk_speed(I<$speed>)

=item $efa->with_bike(I<$bool>)

=back

=head2 STATIC METHODS

=over

=item Travel::Routing::DE::EFA::get_efa_urls()

Returns a list of known EFA entry points. Each list element is a hashref with
the following elements.

=over

=item B<url>: service URL as passed to B<efa_url>

=item B<name>: Name of the entity operating this service

=item B<shortname>: Short name of the entity

=back

=back

=head1 DIAGNOSTICS

When encountering an error, Travel::Routing::DE::EFA throws a
Travel::Routing::DE::EFA::Exception(3pm) object.

=head1 DEPENDENCIES

=over

=item * LWP::UserAgent(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

=over

=item * Travel::Routing::DE::EFA::Exception(3pm)

=item * Travel::Routing::DE::EFA::Route(3pm)

=item * L<WWW::EFA> is another implementation, using L<Moose>.

=back

=head1 AUTHOR

Copyright (C) 2009-2018 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
