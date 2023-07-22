package Travel::Routing::DE::EFA::Route::Message;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '2.21';

Travel::Routing::DE::EFA::Route::Message->mk_ro_accessors(
	qw(is_detailed summary subject subtitle raw_content));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	if ( not defined $ref->{subject} ) {
		$ref->{subject} = $ref->{summary};
	}

	if ( defined $ref->{raw_content} ) {
		$ref->{is_detailed} = 1;
	}
	else {
		$ref->{is_detailed} = 0;
	}

	return bless( $ref, $obj );
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

1;

__END__

=head1 NAME

Travel::Routing::DE::EFA::Route::Message - contains a message related to a
route or route part.

=head1 SYNOPSIS

    for my $m ($routepart->regular_notes, $routepart->current_notes) {
        if ($m->is_detailed) {
            printf("%s: %s\n", $m->subtitle, $m->subject);
        }
        else {
            say $m->summary;
        }
    }

=head1 VERSION

version 2.21

=head1 DESCRIPTION

B<Travel::Routing::DE::EFA::Route::Message> contains information about a
specific route or route part, such as wheelchair accessibility, unscheduled
route diversions and cancelled stops. Often, this information is not used in
the backend's route calculation, so a message may invalidate a certain route or
route part.

There are two types of messages provided by the backend: oneliners and detailed
messages. There is no known distinction regarding their type or content.
Also, there are some other backend-provided fields not yet covered by this
module, so expect changes in future releases.

A oneline message consists of a single string which can be accesed using
B<subject> or B<summary> and its B<is_detailed> accessor returns false.

A detailed message has a subject, subtitle, summary and detailed HTML
content.

=head1 METHODS

=head2 ACCESSORS

=over

=item $message->is_detailed

True if all accessors (fields) are set, false otherwise. When this field
is false, only B<summary> and B<subject> are set (and they will return the
same string).

=item $message->summary

Message summary.

=item $message->subject

Message subject. May be the same string as the subtitle.

=item $message->subtitle

Message subtitle. May be the same string as the summary.

=item $message->raw_content

Raw HTML content. May contain information not available via any other
accessor.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

None.

=head1 BUGS AND LIMITATIONS

This module does not yet provide access to all data provided by the backend.
Most notably, B<raw_content> is not properly parsed yet.

=head1 SEE ALSO

Travel::Routing::DE::EFA(3pm), Travel::Routing::DE::EFA::Route::Part(3pm).

=head1 AUTHOR

Copyright (C) 2015 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This program is licensed under the same terms as Perl itself.
