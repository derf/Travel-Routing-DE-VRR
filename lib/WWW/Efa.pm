package WWW::Efa;

use strict;
use warnings;
use 5.010;

use Carp qw/croak confess/;
use XML::LibXML;
use WWW::Mechanize;

my $VERSION = '1.3+git';

sub new {
	my ($obj, $post) = @_;
	my $ref = {};

	my $firsturl
		= 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2?language=de&itdLPxx_transpCompany=vrr';
	my $posturl = 'http://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2';

	$ref->{'mech'} = WWW::Mechanize->new(
		autocheck => 1,
	);

	$ref->{'mech'}->get($firsturl);
	$ref->{'mech'}->submit_form(
		form_name => 'jp',
		fields    => $post,
	);

	# XXX (workaround)
	# The content actually is iso-8859-1. But HTML::Message doesn't actually
	# decode character strings when they have that encoding. However, it
	# doesn't check for latin-1, which is an alias for iso-8859-1.

	$ref->{'html_reply'} = $ref->{'mech'}->response()->decoded_content(
		charset => 'latin-1'
	);

	return bless($ref, $obj);
}

sub new_from_html {
	my ($obj, $html) = @_;
	my $ref = {};

	$ref->{'html_reply'} = $html;

	return bless($ref, $obj);
}

sub parse_initial {
	my ($tree) = @_;

	my $con_part = 0;
	my $con_no;
	my $cons;

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

	if (defined $con_no) {
		return $cons;
	}
	else {
		confess('efa.vrr.de returned no connections, check your input data');
	}
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

sub parse {
	my ($self) = @_;

	my $tree = XML::LibXML->load_html(
		string => $self->{'html_reply'},
	);

	my $raw_cons = parse_initial($tree);

	for my $raw_con (@{$raw_cons}) {
		push(@{$self->{'connections'}}, parse_pretty($raw_con));
	}
	$self->{'tree'} = $tree;
}

sub check_ambiguous {
	my ($self) = @_;
	my $ambiguous = 0;
	my $tree = $self->{'tree'};

	my $xp_select = XML::LibXML::XPathExpression->new('//select');
	my $xp_option = XML::LibXML::XPathExpression->new('./option');

	foreach my $select (@{$tree->findnodes($xp_select)}) {
		$ambiguous = 1;
		printf {*STDERR} (
			"Ambiguous input for %s\n",
			$select->getAttribute('name'),
		);
		foreach my $val ($select->findnodes($xp_option)) {
			print {*STDERR} "\t";
			say {*STDERR} $val->textContent();
		}
	}
	if ($ambiguous) {
		exit 1;
	}
}

sub check_no_connections {
	my ($self) = @_;
	my $tree = $self->{'tree'};

	my $xp_err_img = XML::LibXML::XPathExpression->new(
		'//td/img[@src="images/ausrufezeichen.jpg"]');

	my $err_node = $tree->findnodes($xp_err_img)->[0];

	if ($err_node) {
		say {*STDERR} 'Looks like efa.vrr.de showed an error.';
		say {*STDERR} 'I will now try to dump the error message:';

		say {*STDERR} $err_node->parentNode()->parentNode()->textContent();

		exit 2;
	}
}

sub connections {
	my ($self) = @_;

	return(@{$self->{'connections'}});
}

1;
