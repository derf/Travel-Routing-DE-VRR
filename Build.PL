#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

my %opts = (
	build_requires => {
		'Test::More' => 0,
		'Test::Compile' => 0,
		'Test::Pod' => 0,
		'Test::Command' => 0,
	},
	module_name => 'Net::Travel::DE::VRR',
	license => 'unrestricted',
	requires => {
		'Class::Accessor' => 0,
		'perl' => '5.10.0',
		'Getopt::Long' => 0,
		'XML::LibXML' => 0,
		'WWW::Mechanize' => 0,
	},
);

if (-d '.git' and qx{which git} =~ qr{/git$}) {
	$opts{'dist_version'} = qx{git describe};
	chomp $opts{'dist_version'};
}

my $build = Module::Build->new(%opts);
$build->create_build_script;
