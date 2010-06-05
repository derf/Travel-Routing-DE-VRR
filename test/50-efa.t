#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::Command tests => 79;

my $efa     = 'bin/efa';
my $testarg = "E HBf MH HBf";
my $test_parse = "--test-parse $testarg";

my $EMPTY = '';

my $re_usage = qr{Insufficient to/from arguments, see \S*efa --help for usage};
my $re_version = qr{\S*efa version \S+};

my $err_exclude = "Invalid argument. See manpage for --exclude usage\n";
my $err_prefer  = "Invalid argument. Usage: --prefer speed|nowait|nowalk\n";
my $err_include = "Invalid argument. Usage: --include local|ic|ice\n";
my $err_time    = "Invalid argument. Usage: --time HH:MM\n";
my $err_date    = "Invalid argument: Usage: --date DD.MM.[YYYY]\n";
my $err_common  = "Please see bin/efa --help\n";

my $err_walk_speed
	= "Invalid argument. Uaseg: --walk-speed normal|fast|slow\n";

# Usage on invalid invocation
my $cmd = Test::Command->new(cmd => "$efa");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_like($re_usage);

$cmd = Test::Command->new(cmd => "$efa E HBf MH");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_like($re_usage);

$cmd = Test::Command->new(cmd => "$efa E HBf Du HBf MH");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq($EMPTY);
$cmd->stderr_like($re_usage);

for my $opt (qw/-e --exclude/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq($err_exclude . $err_common);
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
	$cmd->stderr_is_eq($err_prefer . $err_common);
}

for my $opt (qw/-i --include/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq($err_include . $err_common);
}

for my $opt (qw/-w --walk-speed/) {
	$cmd = Test::Command->new(cmd => "$efa $opt invalid $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq($err_walk_speed . $err_common);
}

for my $opt (qw/-t --time/) {
	$cmd = Test::Command->new(cmd => "$efa $opt 35:12 $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq($err_time . $err_common);
}

for my $opt (qw/-d --date/) {
	$cmd = Test::Command->new(cmd => "$efa $opt 11.23.2010 $testarg");

	$cmd->exit_isnt_num(0);
	$cmd->stdout_is_eq($EMPTY);
	$cmd->stderr_is_eq($err_date . $err_common);
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
	$cmd = Test::Command->new(cmd => "$efa $test_parse < test/dump_$file");

	$cmd->exit_is_num(0);
	$cmd->stdout_is_file("test/parse_$file");
	$cmd->stderr_is_eq($EMPTY);
}

$cmd = Test::Command->new(
	cmd => "$efa $test_parse --ignore-info '.*' < test/dump_e_hbf_b_hbf.ice"
);

$cmd->exit_is_num(0);
$cmd->stdout_is_file("test/parse_e_hbf_b_hbf.ice.ignore_all");
$cmd->stderr_is_eq($EMPTY);

$cmd = Test::Command->new(
	cmd => "$efa $test_parse --ignore-info < test/dump_e_hbf_mh_hbf"
);

$cmd->exit_is_num(0);
$cmd->stdout_is_file("test/parse_e_hbf_mh_hbf.ignore_none");
$cmd->stderr_is_eq($EMPTY);

$cmd = Test::Command->new(
	cmd => "$efa $test_parse < test/dump_ambiguous"
);

$cmd->exit_is_num(1);
$cmd->stdout_is_file('test/parse_ambiguous');
$cmd->stderr_is_eq($EMPTY);
