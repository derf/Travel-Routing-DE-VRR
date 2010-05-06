#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use Test::Command tests => 15;

my $efa = 'bin/efa';
my $testarg = "E HBf MH HBf";

my $re_usage = qr{Insufficient to/from arguments, see \S*efa --help for usage};
my $re_version = qr{\S*efa version \S+};

# Usage on invalid invocation
my $cmd = Test::Command->new(cmd => "$efa");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq('');
$cmd->stderr_like($re_usage);

$cmd = Test::Command->new(cmd => "$efa E HBf MH");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq('');
$cmd->stderr_like($re_usage);

# (primitive) argument checking for --time
$cmd = Test::Command->new(cmd => "$efa --time 35:12 $testarg");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq('');
$cmd->stderr_is_eq("Invalid argument. Usage: --time HH:MM\n");

# (primitive) argument checking for --date
$cmd = Test::Command->new(cmd => "$efa --date 11.23.2010 $testarg");

$cmd->exit_isnt_num(0);
$cmd->stdout_is_eq('');
$cmd->stderr_is_eq("Invalid argument: Usage: --date DD.MM[.YYYY]\n");

# --version
$cmd = Test::Command->new(cmd => "$efa --version");

$cmd->exit_is_num(0);
$cmd->stdout_like($re_version);
$cmd->stderr_is_eq('');
