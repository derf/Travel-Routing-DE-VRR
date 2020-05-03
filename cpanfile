requires 'Class::Accessor';
requires 'Exception::Class';
requires 'Getopt::Long';
requires 'List::Util';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'XML::LibXML';

on test => sub {
	requires 'File::Slurp';
	requires 'Test::Compile';
	requires 'Test::Fatal';
	requires 'Test::More';
	requires 'Test::Pod';
};
