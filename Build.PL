#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

Module::Build->new(

	build_requires => {
		'File::Slurp' => 0,
		'Test::Compile' => 0,
		'Test::Fatal' => 0,
		'Test::More' => 0,
		'Test::Pod' => 0,
	},
	configure_requires => {
		'Module::Build' => 0.40,
	},
	module_name => 'Travel::Routing::DE::VRR',
	license => 'unrestricted',
	requires => {
		'perl' => '5.10.1',
		'Class::Accessor' => 0,
		'Exception::Class' => 0,
		'Getopt::Long' => 0,
		'LWP::UserAgent' => 0,
		'XML::LibXML' => 0,
	},
	sign => 1,
	meta_merge => {
		resources => {
			repository => 'https://github.com/derf/Travel-Routing-DE-VRR'
		}
	},
)->create_build_script();
