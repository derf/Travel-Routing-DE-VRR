package Travel::Routing::DE::VRR;

use strict;
use warnings;

use Carp qw(cluck);
use Encode qw(decode);
use Travel::Routing::DE::VRR::Route;
use LWP::UserAgent;
use XML::LibXML;

use Exception::Class (
	'Travel::Routing::DE::VRR::Exception',
	'Travel::Routing::DE::VRR::Exception::Setup' => {
		isa         => 'Travel::Routing::DE::VRR::Exception',
		description => 'invalid argument on setup',
		fields      => [ 'option', 'have', 'want' ],
	},
	'Travel::Routing::DE::VRR::Exception::Net' => {
		isa         => 'Travel::Routing::DE::VRR::Exception',
		description => 'could not submit POST request',
		fields      => 'http_response',
	},
	'Travel::Routing::DE::VRR::Exception::NoData' => {
		isa         => 'Travel::Routing::DE::VRR::Exception',
		description => 'got no data to parse',
	},
	'Travel::Routing::DE::VRR::Exception::Ambiguous' => {
		isa         => 'Travel::Routing::DE::VRR::Exception',
		description => 'ambiguous input',
		fields      => [ 'post_key', 'possibilities' ],
	},
	'Travel::Routing::DE::VRR::Exception::NoConnections' => {
		isa         => 'Travel::Routing::DE::VRR::Exception',
		description => 'got no connections',
	},
);

our $VERSION = '2.010_5008';

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
		Travel::Routing::DE::VRR::Exception::Setup->throw(
			option => 'time',
			error  => 'Specify either departure_time or arrival_time'
		);
	}

	if ( $time !~ / ^ [0-2]? \d : [0-5]? \d $ /x ) {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
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
		Travel::Routing::DE::VRR::Exception::Setup->throw(
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
				$self->{post}->{"inclMOT_${map_id}"} = undef;
				$ok = 1;
			}
		}
		if ( not $ok ) {
			Travel::Routing::DE::VRR::Exception::Setup->throw(
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

sub select_interchange_by {
	my ( $self, $prefer ) = @_;

	if ($prefer eq 'speed') {
		$self->{post}->{routeType} = 'LEASTTIME';
	}
	elsif ($prefer eq 'waittime') {
		$self->{post}->{routeType} = 'LEASTINTERCHANGE';
	}
	elsif ($prefer eq 'distance') {
		$self->{post}->{routeType} = 'LEASTWALKING';
	}
	else {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
			option => 'select_interchange_by',
			have   => $prefer,
			want   => 'speed / waittime / distance',
		);
	}

	return;
}

sub train_type {
	my ( $self, $include ) = @_;

	if ($include eq 'local') {
		$self->{post}->{lineRestriction} = 403;
	}
	elsif ($include eq 'ic') {
		$self->{post}->{lineRestriction} = 401;
	}
	elsif ($include eq 'ice') {
		$self->{post}->{lineRestriction} = 400;
	}
	else {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
			option => 'train_type',
			have   => $include,
			want   => 'local / ic / ice',
		);
	}

	return;
}

sub use_near_stops {
	my ( $self, $toggle ) = @_;

	$self->{post}->{useProxFootSearch} = $toggle;

	return;
}

sub walk_speed {
	my ( $self, $walk_speed ) = @_;

	if ( $walk_speed ~~ [ 'normal', 'fast', 'slow' ] ) {
		$self->{post}->{changeSpeed} = $walk_speed;
	}
	else {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
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

sub place {
	my ( $self, $which, $place, $stop, $type ) = @_;

	if ( not( $place and $stop ) ) {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
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
		changeSpeed                                        => 'normal',
		command                                            => q{},
		execInst                                           => q{},
		imparedOptionsActive                               => 1,
		inclMOT_0                                          => 'on',
		inclMOT_1                                          => 'on',
		inclMOT_10                                         => 'on',
		inclMOT_11                                         => 'on',
		inclMOT_2                                          => 'on',
		inclMOT_3                                          => 'on',
		inclMOT_4                                          => 'on',
		inclMOT_5                                          => 'on',
		inclMOT_6                                          => 'on',
		inclMOT_7                                          => 'on',
		inclMOT_8                                          => 'on',
		inclMOT_9                                          => 'on',
		includedMeans                                      => 'checkbox',
		itOptionsActive                                    => 1,
		itdDateDay                                         => $now[3],
		itdDateMonth                                       => $now[4] + 1,
		itdDateYear                                        => $now[5] + 1900,
		itdLPxx_ShowFare                                   => q{ },
		itdLPxx_command                                    => q{},
		itdLPxx_enableMobilityRestrictionOptionsWithButton => q{},
		itdLPxx_id_destination                             => ':destination',
		itdLPxx_id_origin                                  => ':origin',
		itdLPxx_id_via                                     => ':via',
		itdLPxx_mapState_destination                       => q{},
		itdLPxx_mapState_origin                            => q{},
		itdLPxx_mapState_via                               => q{},
		itdLPxx_mdvMap2_destination                        => q{},
		itdLPxx_mdvMap2_origin                             => q{},
		itdLPxx_mdvMap2_via                                => q{},
		itdLPxx_mdvMap_destination                         => q{::},
		itdLPxx_mdvMap_origin                              => q{::},
		itdLPxx_mdvMap_via                                 => q{::},
		itdLPxx_priceCalculator                            => q{},
		itdLPxx_transpCompany                              => 'vrr',
		itdLPxx_view                                       => q{},
		itdTimeHour                                        => $now[2],
		itdTimeMinute                                      => $now[1],
		itdTripDateTimeDepArr                              => 'dep',
		language                                           => 'de',
		lineRestriction                                    => 403,
		maxChanges                                         => 9,
		nameInfo_destination                               => 'invalid',
		nameInfo_origin                                    => 'invalid',
		nameInfo_via                                       => 'invalid',
		nameState_destination                              => 'empty',
		nameState_origin                                   => 'empty',
		nameState_via                                      => 'empty',
		name_destination                                   => q{},
		name_origin                                        => q{},
		name_via                                           => q{},
		outputFormat                                       => 'XML',
		placeInfo_destination                              => 'invalid',
		placeInfo_origin                                   => 'invalid',
		placeInfo_via                                      => 'invalid',
		placeState_destination                             => 'empty',
		placeState_origin                                  => 'empty',
		placeState_via                                     => 'empty',
		place_destination                                  => q{},
		place_origin                                       => q{},
		place_via                                          => q{},
		ptOptionsActive                                    => 1,
		requestID                                          => 0,
		routeType                                          => 'LEASTTIME',
		sessionID                                          => 0,
		text                                               => 1993,
		trITArrMOT                                         => 100,
		trITArrMOTvalue100                                 => 8,
		trITArrMOTvalue101                                 => 10,
		trITArrMOTvalue104                                 => 10,
		trITArrMOTvalue105                                 => 10,
		trITDepMOT                                         => 100,
		trITDepMOTvalue100                                 => 8,
		trITDepMOTvalue101                                 => 10,
		trITDepMOTvalue104                                 => 10,
		trITDepMOTvalue105                                 => 10,
		typeInfo_destination                               => 'invalid',
		typeInfo_origin                                    => 'invalid',
		typeInfo_via                                       => 'invalid',
		type_destination                                   => 'stop',
		type_origin                                        => 'stop',
		type_via                                           => 'stop',
		useRealtime                                        => 1
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
	if ( $conf->{select_interchange_by} ) {
		$self->select_interchange_by( $conf->{select_interchange_by} );
	}
	if ( $conf->{use_near_stops} ) {
		$self->use_near_stops(1);
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

	return;
}

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = {};

	$ref->{config} = \%conf;

	bless( $ref, $obj );

	$ref->create_post();

	if ( not( defined $conf{submit} and $conf{submit} == 0 ) ) {
		$ref->submit( %{ $conf{lwp_options} } );
	}

	return $ref;
}

sub new_from_xml {
	my ( $class, %opt ) = @_;

	my $self = { xml_reply => $opt{xml} };

	bless( $self, $class );

	$self->parse();

	return $self;
}

sub submit {
	my ( $self, %conf ) = @_;

	$self->{ua} = LWP::UserAgent->new(%conf);

	my $response = $self->{ua}
	  ->post( 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2', $self->{post} );

	if ( $response->is_error ) {
		Travel::Routing::DE::VRR::Exception::Net->throw(
			http_response => $response, );
	}

	$self->{xml_reply} = $response->decoded_content;

	$self->parse();

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

sub parse_part {
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
	my $xp_mot   = XML::LibXML::XPathExpression->new('./itdMeansOfTransport');
	my $xp_delay = XML::LibXML::XPathExpression->new('./itdRBLControlled');
	my $xp_info
	  = XML::LibXML::XPathExpression->new('./itdInfoTextList/infoTextListElem');

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

		my $e_dep    = ( $e->findnodes($xp_dep) )[0];
		my $e_arr    = ( $e->findnodes($xp_arr) )[0];
		my $e_ddate  = ( $e_dep->findnodes($xp_date) )[0];
		my $e_dtime  = ( $e_dep->findnodes($xp_time) )[0];
		my $e_dsdate = ( $e_dep->findnodes($xp_sdate) )[0];
		my $e_dstime = ( $e_dep->findnodes($xp_stime) )[0];
		my $e_adate  = ( $e_arr->findnodes($xp_date) )[0];
		my $e_atime  = ( $e_arr->findnodes($xp_time) )[0];
		my $e_asdate = ( $e_arr->findnodes($xp_sdate) )[0];
		my $e_astime = ( $e_arr->findnodes($xp_stime) )[0];
		my $e_mot    = ( $e->findnodes($xp_mot) )[0];
		my $e_delay  = ( $e->findnodes($xp_delay) )[0];
		my @e_info   = $e->findnodes($xp_info);

		my $delay = $e_delay ? $e_delay->getAttribute('delayMinutes') : 0;

		my $hash = {
			delay              => $delay,
			departure_date     => $self->itddate_str($e_ddate),
			departure_time     => $self->itdtime_str($e_dtime),
			departure_sdate    => $self->itddate_str($e_dsdate),
			departure_stime    => $self->itdtime_str($e_dstime),
			departure_stop     => $e_dep->getAttribute('name'),
			departure_platform => $e_dep->getAttribute('platformName'),
			train_line         => $e_mot->getAttribute('name'),
			train_destination  => $e_mot->getAttribute('destination'),
			arrival_date       => $self->itddate_str($e_adate),
			arrival_time       => $self->itdtime_str($e_atime),
			arrival_sdate      => $self->itddate_str($e_asdate),
			arrival_stime      => $self->itdtime_str($e_astime),
			arrival_stop       => $e_arr->getAttribute('name'),
			arrival_platform   => $e_arr->getAttribute('platformName'),
		};

		for my $key ( keys %{$hash} ) {
			$hash->{$key} = decode( 'UTF-8', $hash->{$key} );
		}

		for my $ve ( $e->findnodes($xp_via) ) {
			my $e_vdate = ( $ve->findnodes($xp_date) )[-1];
			my $e_vtime = ( $ve->findnodes($xp_time) )[-1];

			if ( not( $e_vdate and $e_vtime )
				or ( $e_vdate->getAttribute('weekday') == -1 ) )
			{
				next;
			}

			my $name = decode( 'UTF-8', $ve->getAttribute('name') );
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

		$hash->{extra} = [ map { decode( 'UTF-8', $_->textContent ) } @e_info ];

		push( @route_parts, $hash );
	}

	push(
		@{ $self->{routes} },
		Travel::Routing::DE::VRR::Route->new( $info, @route_parts )
	);

	return;
}

sub parse {
	my ($self) = @_;

	my $tree = $self->{tree}
	  = XML::LibXML->load_xml( string => $self->{xml_reply}, );

	my $xp_element = XML::LibXML::XPathExpression->new(
		'//itdItinerary/itdRouteList/itdRoute');
	my $xp_odv = XML::LibXML::XPathExpression->new('//itdOdv');

	for my $odv ( $tree->findnodes($xp_odv) ) {
		$self->check_ambiguous($odv);
	}

	for my $part ( $tree->findnodes($xp_element) ) {
		$self->parse_part($part);
	}

	if ( @{ $self->{routes} } == 0 ) {
		Travel::Routing::DE::VRR::Exception::NoData->throw();
	}

	return 1;
}

sub check_ambiguous {
	my ( $self, $tree ) = @_;

	my $xp_place = XML::LibXML::XPathExpression->new('./itdOdvPlace');
	my $xp_name  = XML::LibXML::XPathExpression->new('./itdOdvName');

	my $xp_place_elem = XML::LibXML::XPathExpression->new('./odvPlaceElem');
	my $xp_name_elem  = XML::LibXML::XPathExpression->new('./odvNameElem');

	my $e_place = ( $tree->findnodes($xp_place) )[0];
	my $e_name  = ( $tree->findnodes($xp_name) )[0];

	if ( not( $e_place and $e_name ) ) {
		cluck('skipping ambiguity check - itdOdvPlace/itdOdvName missing');
		return;
	}

	my $s_place = $e_place->getAttribute('state');
	my $s_name  = $e_name->getAttribute('state');

	if ( $s_place eq 'list' ) {
		Travel::Routing::DE::VRR::Exception::Ambiguous->throw(
			post_key      => 'place',
			possibilities => join( q{ | },
				map { decode( 'UTF-8', $_->textContent ) }
				  @{ $e_place->findnodes($xp_place_elem) } )
		);
	}
	if ( $s_name eq 'list' ) {
		Travel::Routing::DE::VRR::Exception::Ambiguous->throw(
			post_key      => 'name',
			possibilities => join( q{ | },
				map { decode( 'UTF-8', $_->textContent ) }
				  @{ $e_name->findnodes($xp_name_elem) } )
		);
	}

	if ( $s_place eq 'notidentified' ) {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
			option => 'place',
			error  => 'unknown place (typo?)'
		);
	}
	if ( $s_name eq 'notidentified' ) {
		Travel::Routing::DE::VRR::Exception::Setup->throw(
			option => 'name',
			error  => 'unknown name (typo?)'
		);
	}

	# 'identified' and 'empty' are ok

	return;
}

sub routes {
	my ($self) = @_;

	return @{ $self->{routes} };
}

1;

__END__

=head1 NAME

Travel::Routing::DE::VRR - unofficial interface to the efa.vrr.de German itinerary service

=head1 SYNOPSIS

	use Travel::Routing::DE::VRR;

	my $efa = Travel::Routing::DE::VRR->new(
		origin      => [ 'Essen',    'HBf' ],
		destination => [ 'Duisburg', 'HBf' ],
	);

	for my $route ( $efa->routes ) {
		for my $part ( $route->parts ) {
			printf(
				"%s at %s -> %s at %s, via %s to %s",
				$part->departure_time, $part->departure_stop,
				$part->arrival_time,   $part->arrival_stop,
				$part->train_line,     $part->train_destination,
			);
		}
		print "\n\n";
	}

=head1 VERSION

version 2.010_5008

=head1 DESCRIPTION

B<Travel::Routing::DE::VRR> is a client for the efa.vrr.de web interface.
You pass it the start/stop of your journey, maybe a time and a date and more
details, and it returns the up-to-date scheduled connections between those two
stops.

It uses B<LWP::UserAgent> and B<XML::LibXML> for this.

=head1 METHODS

=over

=item $efa = Travel::Routing::DE::VRR->new(I<%opts>)

Returns a new Travel::Routing::DE::VRR object and sets up its POST data via
%opts.

Valid hash keys and their values are:

=over

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

Journey date.  Default: tdoay

=item B<exclude> => \@exclude

Do not use certain transport types for itinerary.  Accepted arguments:
zug, s-bahn, u-bahn, stadtbahn, tram, stadtbus, regionalbus, schnellbus,
seilbahn, schiff, ast, sonstige

=item B<max_interchanges> => I<num>

Set maximum number of interchanges

=item B<select_interchange_by> => B<speed>|B<waittime>|B<distance>

Prefer either fast connections (default), connections with low wait time or
connections with little distance to walk

=item B<use_near_stops> => B<0>|B<1>

If true: Try using near stops instead of the specified origin/destination ones

=item B<train_type> => B<local>|B<ic>|B<ice>

Include only local trains into itinarery (default), all but ICEs, or all.

The latter two are usually way more expensive for short routes.

=item B<walk_speed> => B<slow>|B<fast>|B<normal>

Set walk speed.  Default: B<normal>

=item B<with_bike> => B<0>|B<1>

If true: Prefer connections allowing passengers with bikes

=item B<lwp_options> => I<\%hashref>

Options to pass to C<< LWP::UserAgent->new >>.

=item B<submit> => B<0>|B<1>

By default, B<new> will create a POST request and submit it to
L<http://efa.vrr.de>. If you do not want it to be submitted yet, set this to
B<0>.

=back

=item $efa->submit(I<%opts>)

Submit the query to L<http://efa.vrr.de>.
I<%opts> is passed on to C<< LWP::UserAgent->new >>.

=item $efa->routes()

Returns a list of Travel::Routing::DE::VRR::Route(3pm) elements. Each one contains
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

=item $efa->use_near_stops(I<$bool>)

=item $efa->walk_speed(I<$speed>)

=item $efa->with_bike(I<$bool>)

=back

=head1 DIAGNOSTICS

When encountering an error, Travel::Routing::DE::VRR throws a
Travel::Routing::DE::VRR::Exception(3pm) object.

=head1 DEPENDENCIES

=over

=item * LWP::UserAgent(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

It is best not to pass Unicode characters to B<Travel::Routing::DE::VRR>.

=head1 SEE ALSO

=over

=item * Travel::Routing::DE::VRR::Exception(3pm)

=item * Travel::Routing::DE::VRR::Route(3pm)

=item * L<WWW::EFA> is another implementation, using L<Moose>.

=back

=head1 AUTHOR

Copyright (C) 2009-2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

  0. You just DO WHAT THE FUCK YOU WANT TO.
