#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::Command tests => 85;

my $efa     = 'bin/efa';
my $testarg = "E HBf MH HBf";
my $test_parse = "--test-parse $testarg";

my $EMPTY = '';

my $re_version = qr{\S*efa version \S+};

sub mk_err {
	my ($arg, $value, $message) = @_;
	return sprintf(
		"WWW::Efa config error: Wrong arg for option %s: %s\n%s\n",
		$arg, $value, $message
	);
}

# Usage on invalid invocation
my $cmd = Test::Command->new(cmd => "$efa");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_eq(
	mk_err('place', 'origin', 'Need at least two elements')
);

$cmd = Test::Command->new(cmd => "$efa E HBf MH");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_eq(
	mk_err('place', 'origin', 'Need at least two elements')
);

$cmd = Test::Command->new(cmd => "$efa E HBf Du HBf MH");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_eq(
	mk_err('place', 'origin', 'Need at least two elements')
);

for my $opt (qw/-e --exclude/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('exclude', 'invalid', 'Must consist of zug s-bahn u-bahn stadtbahn tram stadtbus regionalbus schnellbus seilbahn schiff ast sonstige')
	);
}

for my $opt (qw/-m --max-change/) {
	$cmd = Test::Command->new(cmd => "$efa $opt nan $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	# no stderr test - depends on Getopt::Long
}

for my $opt (qw/-P --prefer/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('prefer', 'invalid', 'Must be either speed, nowait or nowalk')
	);
}

for my $opt (qw/-i --include/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('include', 'invalid', 'Must be one of local/ic/ice')
	);
}

for my $opt (qw/-w --walk-speed/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('walk_speed', 'invalid', 'Must be normal, fast or slow')
	);
}

for my $opt (qw/-t --time --depart -a --arrive/) {
	$cmd = Test::Command->new(cmd => "$efa $opt 35:12 $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('time', '35:12', 'Must match HH:MM')
	);
}

for my $opt (qw/-d --date/) {
	$cmd = Test::Command->new(cmd => "$efa $opt 11.23.2010 $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq(
		mk_err('date', '11.23.2010', 'Must match DD.MM.[YYYY]')
	);
}

for my $opt (qw/-v --version/) {
	$cmd = Test::Command->new(cmd => "$efa $opt");

	$cmd->exit_is_num(0);
	$cmd->stdout_like($re_version);
	$cmd->stderr_is_eq($EMPTY);
}


for my $file (qw{
	e_hbf_mh_hbf
	e_hbf_du_hbf.ice
	e_werden_e_hbf
	e_hbf_b_hbf.ice
	e_martinstr_e_florastr
	})
{
	$cmd = Test::Command->new(cmd => "$efa $test_parse < t/in/$file");

	$cmd->exit_is_num(0);
	$cmd->stdout_is_file("t/out/$file");
	$cmd->stderr_is_eq($EMPTY);
}

$cmd = Test::Command->new(
	cmd => "$efa $test_parse --ignore-info '.*' < t/in/e_hbf_b_hbf.ice"
);

$cmd->exit_is_num(0);
$cmd->stdout_is_file("t/out/e_hbf_b_hbf.ice.ignore_all");
$cmd->stderr_is_eq($EMPTY);

$cmd = Test::Command->new(
	cmd => "$efa $test_parse --ignore-info '' < t/in/e_hbf_mh_hbf"
);

$cmd->exit_is_num(0);
$cmd->stdout_is_file("t/out/e_hbf_mh_hbf.ignore_none");
$cmd->stderr_is_eq($EMPTY);

__END__

$cmd = Test::Command->new(
	cmd => "$efa $test_parse < t/in/ambiguous"
);

$cmd->exit_is_num(1);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_file('t/out/ambiguous');

$cmd = Test::Command->new(
	cmd => "$efa $test_parse < t/in/no_connections"
);

$cmd->exit_is_num(2);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_file('t/out/no_connections');

$cmd = Test::Command->new(
	cmd => "$efa $test_parse < t/in/invalid_input"
);

$cmd->exit_is_num(3);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_is_file('t/out/invalid_input');
