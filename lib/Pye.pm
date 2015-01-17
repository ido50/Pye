package Pye;

# ABSTRACT: Session-based logging platform on top of MongoDB

use Carp;
use Role::Tiny;

our $VERSION = "2.000000";
$VERSION = eval $VERSION;

=head1 NAME

Pye - Session-based logging platform on top of MongoDB

=head1 SYNOPSIS

	use Pye;

	my $pye = Pye->new;

	# on session/request/run/whatever:
	$pye->log($session_id, "Some log message", { data => 'example data' });

=head1 DESCRIPTION

C<Pye> is a dead-simple, session-based logging platform on top of L<MongoDB>.
I built C<Pye> due to my frustration with file-based loggers that generate logs
that are extremely difficult to read, analyze and maintain.

C<Pye> is most useful for services (e.g. web apps) that handle requests,
or otherwise work in sessions, but can be useful in virtually any application,
including automatic (e.g. cron) scripts.

In order to use C<Pye>, your program must define an ID for every session. "Session"
can really mean anything here: a client session in a web service, a request to your
web service, an execution of a script, whatever. As long as a unique ID can be generated,
C<Pye> can handle logging for you.

Main features:

=over

=item * B<Supporting data>

With C<Pye>, any complex data structure (i.e. hash) can be attached to any log message,
enabling you to illustrate a situation, display complex data, etc.

=item * B<No log levels>

Yeah, I consider this a feature. Log levels are a bother, and I don't need them. All log
messages in C<Pye> are saved into the database, nothing gets lost.

=item * B<Easy inspection>

C<Pye> comes with a command line utility, L<pye>, that offers quick inspection of the log.
You can easily view a list of current/latest sessions and read the log of a specific session.
No more mucking about through endless log files, trying to understand which lines belong to which
session, or trying to find that area of the file with messages from that certain date your software
died on.

=back

=cut

requires qw/log session_log list_sessions _remove_session_logs/;

=head1 CONFIGURATION AND ENVIRONMENT
  
C<Pye> requires no configuration files or environment variables.

=head1 DEPENDENCIES

C<Pye> depends on the following CPAN modules:

=over

=item * Carp

=item * MongoDB

=item * Tie::IxHash

=back

The command line utility, L<pye>, depends on:

=over

=item *  Getopt::Compact

=item *  JSON

=item *  Term::ANSIColor

=item *  Text::SpanningTable

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-Pye@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Pye>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Pye

You can also look for information at:

=over 4
 
=item * RT: CPAN's request tracker
 
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Pye>
 
=item * AnnoCPAN: Annotated CPAN documentation
 
L<http://annocpan.org/dist/Pye>
 
=item * CPAN Ratings
 
L<http://cpanratings.perl.org/d/Pye>
 
=item * Search CPAN
 
L<http://search.cpan.org/dist/Pye/>
 
=back
 
=head1 AUTHOR
 
Ido Perlmuter <ido@ido50.net>
 
=head1 LICENSE AND COPYRIGHT
 
Copyright (c) 2013-2015, Ido Perlmuter C<< ido@ido50.net >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, either version
5.8.1 or any later version. See L<perlartistic|perlartistic>
and L<perlgpl|perlgpl>.
 
The full text of the license can be found in the
LICENSE file included with this module.
 
=head1 DISCLAIMER OF WARRANTY
 
BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.
 
IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
__END__
