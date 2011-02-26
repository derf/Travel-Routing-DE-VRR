package WWW::Efa;

=head1 NAME

WWW::Efa - inofficial interface to the efa.vrr.de German itinerary service

=head1 SYNOPSIS

    use WWW::Efa;

    my $efa = WWW::Efa->new(
        from => ['Essen', 'HBf'],
        to   => ['Duisburg', 'HBf'],
    );

    $efa->submit();
    $efa->parse();

    for my $con ($efa->connections()) {
        for my $c (@{$con}) {
            printf(
                "%-5s ab  %-30s %-20s %s\n%-5s an  %-30s\n\n",,
                @{$c}{'dep_time', 'dep_stop', 'train_line', 'train_dest'},
                @{$c}{'arr_time', 'arr_stop'},
            );
        }
        print "\n\n";
    }

=head1 DESCRIPTION

B<WWW::Efa> is a client for the efa.vrr.de web interface.
You pass it the start/stop of your journey, maybe a time and a date and more
details, and it returns the up-to-date scheduled connections between those two
stops.

It uses B<LWP::USerAgent> and B<XML::LibXML> for this.

=cut

use strict;
use warnings;
use 5.010;

use base 'Exporter';

use LWP::UserAgent;
use XML::LibXML;
use WWW::Efa::Error::Ambiguous;
use WWW::Efa::Error::Backend;
use WWW::Efa::Error::NoData;
use WWW::Efa::Error::Setup;

our @EXPORT_OK = ();
my $VERSION = '1.3+git';

sub post_time {
	my ($post, $conf) = @_;
	my $time;

	if ($conf->{'depart'}) {
		$post->{'itdTripDateTimeDepArr'} = 'dep';
		$time = $conf->{'depart'} || $conf->{'time'};
	}
	else {
		$post->{'itdTripDateTimeDepArr'} = 'arr';
		$time = $conf->{'arrive'};
	}

	if ($time !~ / ^ [0-2]? \d : [0-5]? \d $ /x) {
		die WWW::Efa::Error::Setup->new(
			($conf->{'depart'} ? 'depart' : 'arrive'),
			$time, 'Must match HH:MM'
		);
	}
	@{$post}{'itdTimeHour', 'itdTimeMinute'} = split(/:/, $time);
}

sub post_date {
	my ($post, $date) = @_;

	if ($date !~ /^ [0-3]? \d \. [01]? \d (?: | \. | \. (?: \d{4} ))? $/x) {
		die WWW::Efa::Error::Setup->new(
			'date', $date, 'Must match DD.MM.[YYYY]'
		);
	}
	@{$post}{'itdDateDay', 'itdDateMonth', 'itdDateYear'} = split(/\./, $date);
	$post->{'itdDateYear'} //= (localtime(time))[5] + 1900;
}

sub post_exclude {
	my ($post, @exclude) = @_;
	my @mapping = qw{
		zug s-bahn u-bahn stadtbahn tram stadtbus regionalbus
		schnellbus seilbahn schiff ast sonstige
	};

	foreach my $exclude_type (@exclude) {
		my $ok = 0;
		for my $map_id (0 .. $#mapping) {
			if ($exclude_type eq $mapping[$map_id]) {
				$post->{"inclMOT_${map_id}"} = undef;
				$ok = 1;
			}
		}
		if (not $ok) {
			die WWW::Efa::Error::Setup->new(
				'exclude',
				join(q{ }, @exclude),
				'Must consist of ' . join(q{ }, @mapping)
			);
		}
	}
}

sub post_prefer {
	my ($post, $prefer) = @_;

	given ($prefer) {
		when ('speed')  { $post->{'routeType'} = 'LEASTTIME' }
		when ('nowait') { $post->{'routeType'} = 'LEASTINTERCHANGE' }
		when ('nowalk') { $post->{'routeType'} = 'LEASTWALKING' }
		default {
			die WWW::Efa::Error::Setup->new(
				'prefer', $prefer, 'Must be either speed, nowait or nowalk'
			);
		}
	}
}

sub post_include {
	my ($post, $include) = @_;

	given ($include) {
		when ('local') { $post->{'lineRestriction'} = 403 }
		when ('ic')    { $post->{'lineRestriction'} = 401 }
		when ('ice')   { $post->{'lineRestriction'} = 400 }
		default {
			die WWW::Efa::Error::Setup->new(
				'include', $include, 'Must be one of local/ic/ice'
			);
		}
	}
}

sub post_walk_speed {
	my ($post, $walk_speed) = @_;

	if ($walk_speed ~~ ['normal', 'fast', 'slow']) {
		$post->{'changeSpeed'} = $walk_speed;
	}
	else {
		die WWW::Efa::Error::Setup->new(
			'walk_speed', $walk_speed, 'Must be normal, fast or slow'
		);
	}
}

sub post_place {
	my ($post, $which, $place, $stop, $type) = @_;

	if (not ($place and $stop)) {
		die WWW::Efa::Error::Setup->new(
			'place', $which, 'Need at least two elements'
		);
	}

	$type //= 'stop';

	@{$post}{"place_${which}", "name_${which}"} = ($place, $stop);

	if ($type ~~ [qw[address poi stop]]) {
		$post->{"type_${which}"} = $type;
	}
}

sub create_post {
	my ($conf) = @_;
	my @now = localtime(time());
	my $post = {
		changeSpeed => "normal",
		command => "",
		execInst => "",
		imparedOptionsActive => 1,
		inclMOT_0 => "on",
		inclMOT_1 => "on",
		inclMOT_10 => "on",
		inclMOT_11 => "on",
		inclMOT_2 => "on",
		inclMOT_3 => "on",
		inclMOT_4 => "on",
		inclMOT_5 => "on",
		inclMOT_6 => "on",
		inclMOT_7 => "on",
		inclMOT_8 => "on",
		inclMOT_9 => "on",
		includedMeans => "checkbox",
		itOptionsActive => 1,
		itdDateDay => $now[3],
		itdDateMonth => $now[4] + 1,
		itdDateYear => $now[5] + 1900,
		itdLPxx_ShowFare => " ",
		itdLPxx_command => "",
		itdLPxx_enableMobilityRestrictionOptionsWithButton => "",
		itdLPxx_id_destination => ":destination",
		itdLPxx_id_origin => ":origin",
		itdLPxx_id_via => ":via",
		itdLPxx_mapState_destination => "",
		itdLPxx_mapState_origin => "",
		itdLPxx_mapState_via => "",
		itdLPxx_mdvMap2_destination => "",
		itdLPxx_mdvMap2_origin => "",
		itdLPxx_mdvMap2_via => "",
		itdLPxx_mdvMap_destination => "::",
		itdLPxx_mdvMap_origin => "::",
		itdLPxx_mdvMap_via => "::",
		itdLPxx_priceCalculator => "",
		itdLPxx_transpCompany => "vrr",
		itdLPxx_view => "",
		itdTimeHour => $now[2],
		itdTimeMinute => $now[1],
		itdTripDateTimeDepArr => "dep",
		language => "de",
		lineRestriction => 403,
		maxChanges => 9,
		nameInfo_destination => "invalid",
		nameInfo_origin => "invalid",
		nameInfo_via => "invalid",
		nameState_destination => "empty",
		nameState_origin => "empty",
		nameState_via => "empty",
		name_destination => "",
		name_origin => "",
		name_via => "",
		placeInfo_destination => "invalid",
		placeInfo_origin => "invalid",
		placeInfo_via => "invalid",
		placeState_destination => "empty",
		placeState_origin => "empty",
		placeState_via => "empty",
		place_destination => "",
		place_origin => "",
		place_via => "",
		ptOptionsActive => 1,
		requestID => 0,
		routeType => "LEASTTIME",
		sessionID => 0,
		text => 1993,
		trITArrMOT => 100,
		trITArrMOTvalue100 => 8,
		trITArrMOTvalue101 => 10,
		trITArrMOTvalue104 => 10,
		trITArrMOTvalue105 => 10,
		trITDepMOT => 100,
		trITDepMOTvalue100 => 8,
		trITDepMOTvalue101 => 10,
		trITDepMOTvalue104 => 10,
		trITDepMOTvalue105 => 10,
		typeInfo_destination => "invalid",
		typeInfo_origin => "invalid",
		typeInfo_via => "invalid",
		type_destination => "stop",
		type_origin => "stop",
		type_via => "stop",
		useRealtime => 1
	};


	post_place($post, 'origin', @{$conf->{'from'}});
	post_place($post, 'destination', @{$conf->{'to'}});

	if ($conf->{'via'}) {
		post_place($post, 'via', @{$conf->{'via'}});
	}
	if ($conf->{'arrive'} || $conf->{'depart'}) {
		post_time($post, $conf);
	}
	if ($conf->{'date'}) {
		post_date($post, $conf->{'date'});
	}
	if ($conf->{'exclude'}) {
		post_exclude($post, @{$conf->{'exclude'}});
	}
	if ($conf->{'max_interchanges'}) {
		$post->{'maxChanges'} = $conf->{'max_interchanges'};
	}
	if ($conf->{'prefer'}) {
		post_prefer($post, $conf->{'prefer'});
	}
	if ($conf->{'proximity'}) {
		$post->{'useProxFootSearch'} = 1;
	}
	if ($conf->{'include'}) {
		post_include($post, $conf->{'include'});
	}
	if ($conf->{'walk_speed'}) {
		post_walk_speed($post, $conf->{'walk_speed'});
	}
	if ($conf->{'bike'}) {
		$post->{'bikeTakeAlong'} = 1;
	}

	return $post;
}

sub parse_initial {
	my ($tree) = @_;

	my $con_part = 0;
	my $con_no;
	my $cons = [];

	my $xp_td = XML::LibXML::XPathExpression->new('//table//table/tr/td');
	my $xp_img = XML::LibXML::XPathExpression->new('./img');

	foreach my $td (@{$tree->findnodes($xp_td)}) {

		my $colspan = $td->getAttribute('colspan') // 0;
		my $class   = $td->getAttribute('class')   // q{};

		if ( $colspan != 8 and $class !~ /^bgColor2?$/ ) {
			next;
		}

		if ($colspan == 8) {
			if ($td->textContent() =~ / (?<no> \d+ ) \. .+ Fahrt /x) {
				$con_no = $+{'no'} - 1;
				$con_part = 0;
				next;
			}
		}

		if ($class =~ /^bgColor2?$/) {
			if ($class eq 'bgColor' and ($con_part % 2) == 1) {
				$con_part++;
			}
			elsif ($class eq 'bgColor2' and ($con_part % 2) == 0) {
				$con_part++;
			}
		}

		if (
			defined $con_no and not $td->exists($xp_img)
			and $td->textContent() !~ /^\s*$/
			)
		{
			push(@{$cons->[$con_no]->[$con_part]}, $td->textContent());
		}
	}

	return $cons;
}

sub parse_pretty {
	my ($con_parts) = @_;
	my $elements;
	my @next_extra;

	for my $con (@{$con_parts}) {

		my $hash;

		# Note: Changes @{$con} elements
		foreach my $str (@{$con}) {
			$str =~ s/[\s\n\t]+/ /gs;
			$str =~ s/^ //;
			$str =~ s/ $//;
		}

		if (@{$con} < 5) {
			@next_extra = @{$con};
			next;
		}

		# @extra may contain undef values
		foreach my $extra (@next_extra) {
			if ($extra) {
				push(@{$hash->{'extra'}}, $extra);
			}
		}
		@next_extra = undef;

		if ($con->[0] !~ / \d{2} : \d{2} /ox) {
			splice(@{$con}, 0, 0, q{});
			splice(@{$con}, 4, 0, q{});
			$con->[7] = q{};
		}
		elsif ($con->[4] =~ / Plan: \s ab /ox) {
			push(@{$hash->{'extra'}}, splice(@{$con}, 4, 1));
		}

		foreach my $extra (splice(@{$con}, 8, -1)) {
			push (@{$hash->{'extra'}}, $extra);
		}

		$hash->{'dep_time'}   = $con->[0];
		# always "ab"           $con->[1];
		$hash->{'dep_stop'}   = $con->[2];
		$hash->{'train_line'} = $con->[3];
		$hash->{'arr_time'}   = $con->[4];
		# always "an"           $con->[5];
		$hash->{'arr_stop'}   = $con->[6];
		$hash->{'train_dest'} = $con->[7];

		push(@{$elements}, $hash);
	}
	return($elements);
}

=head1 METHODS

=head2 new(%conf)

Returns a new WWW::Efa object and sets up its POST data via %conf.

Valid hash keys and their values are:

=over

=item B<from> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Mandatory.  Sets the origin, which is the start of the journey.
I<type> is optional and may be one of B<stop> (default), B<address> (street
and house number) or B<poi> ("point of interest").

=item B<to> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Mandatory.  Sets the destination, see B<from>.

=item B<via> => B<[> I<city>B<,> I<stop> [ B<,> I<type> ] B<]>

Optional.  Specifies a intermediate stop which the resulting itinerary must
contain.  See B<from> for arguments.

=item B<arrive> => I<HH:MM>

Sets the journey end time

=item B<depart> => I<HH:MM>

Sets the journey start time

=item B<date> => I<DD.MM.>[I<YYYY>]

Set journey date, in case it is not today

=item B<exclude> => \@exclude

Do not use certain transport types for itinerary.  Acceptep arguments:
zug, s-bahn, u-bahn, stadtbahn, tram, stadtbus, regionalbus, schnellbus,
seilbahn, schiff, ast, sonstige

=item B<max_interchanges> => I<num>

Set maximum number of interchanges

=item B<prefer> => B<speed>|B<nowait>|B<nowalk>

Prefer either fast connections (default), connections with low wait time or
connections with little distance to walk

=item B<proximity> => I<int>

Try using near stops instead of the given start/stop one if I<int> is true.

=item B<include> => B<local>|B<ic>|B<ice>

Include only local trains into itinarery (default), or all but ICEs, or all.

=item B<walk_speed> => B<slow>|B<fast>|B<normal>

Set walk speed.  Default: B<normal>

=item B<bike> => I<int>

If true: Prefer connections allowing to take a bike along

=back

When encountering invalid hash keys, a WWW::Efa::Error object is stored to be
retrieved by $efa->error();

=cut

sub new {
	my ($obj, %conf) = @_;
	my $ref = {};

	$ref->{'config'} = \%conf;

	eval {
		$ref->{'post'} = create_post(\%conf);
	};
	if ($@ and ref($@) eq 'WWW::Efa::Error::Setup') {
		$ref->{'error'} = $@;
	}

	return bless($ref, $obj);
}

=head2 $efa->error()

In case a WWW::Efa operation encountered an error, this returns a
B<WWW::Efa::Error> object related to the exact error. Otherwise, returns
undef.

=cut

sub error {
	my ($self) = @_;

	if ($self->{'error'}) {
		return $self->{'error'};
	}
	return;
}

=head2 $efa->submit(%opts)

Submit the query to B<http://efa.vrr.de>.
B<%opts> is passed on to LWP::UserAgent->new(%opts).

=cut

sub submit {
	my ($self, %conf) = @_;

	$conf{'autocheck'} = 1;

	$self->{'ua'} = LWP::UserAgent->new(%conf);

	my $response
		= $self->{'ua'}->post('http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2',
		                      $self->{post});

	# XXX (workaround)
	# The content actually is iso-8859-1. But HTML::Message doesn't actually
	# decode character strings when they have that encoding. However, it
	# doesn't check for latin-1, which is an alias for iso-8859-1.

	$self->{'html_reply'} = $response->decoded_content(
		charset => 'latin-1'
	);
}

=head2 $efa->parse()

Parse the B<efa.vrr.de> reply.
returns a true value on success. Upon failure, returns undef and sets
$efa->error() to a WWW::Efa::Error object.

=cut

sub parse {
	my ($self) = @_;
	my $err;

	my $tree = XML::LibXML->load_html(
		string => $self->{'html_reply'},
	);

	my $raw_cons = parse_initial($tree);

	if (@{$raw_cons} == 0) {
		$self->{'error'} = WWW::Efa::Error::NoData->new();
	}

	for my $raw_con (@{$raw_cons}) {
		push(@{$self->{'connections'}}, parse_pretty($raw_con));
	}
	$self->{'tree'} = $tree;

	if ($err = $self->check_ambiguous()) {
		$self->{'error'} = $err;
	}
	elsif ($err = $self->check_no_connections()) {
		$self->{'error'} = $err;
	}

	if ($self->{'error'}) {
		return;
	}

	return 1;
}

sub check_ambiguous {
	my ($self) = @_;
	my $tree = $self->{'tree'};

	my $xp_select = XML::LibXML::XPathExpression->new('//select');
	my $xp_option = XML::LibXML::XPathExpression->new('./option');

	foreach my $select (@{$tree->findnodes($xp_select)}) {

		my $post_key = $select->getAttribute('name');
		my @possible;

		foreach my $val ($select->findnodes($xp_option)) {
			push(@possible, $val->textContent());
		}

		return WWW::Efa::Error::Ambiguous->new(
			$post_key,
			@possible,
		);
	}
}

sub check_no_connections {
	my ($self) = @_;
	my $tree = $self->{'tree'};

	my $xp_err_img = XML::LibXML::XPathExpression->new(
		'//td/img[@src="images/ausrufezeichen.jpg"]');

	my $err_node = $tree->findnodes($xp_err_img)->[0];

	if ($err_node) {
		return WWW::Efa::Error::Backend->new(
			$err_node->parentNode()->parentNode()->textContent()
		);
	}
}

=head2 $efa->connections()

Returns an array of connection elements. Each connection element is an
arrayref of connection part, and each connecton part is a hash containing the
following elements:

=over

=item * dep_time

Departure time as a string in HH:MM format

=item * dep_stop

Departure stop, e.g. "Essen HBf"

=item * train_line

Name of the train line, e.g. "S-Bahn S6"

=item * arr_time

Arrival time as a string in HH:MM format

=item * arr_stop

Arrival stop, e.g. "Berlin HBf"

=back

=cut

sub connections {
	my ($self) = @_;

	return(@{$self->{'connections'}});
}

1;