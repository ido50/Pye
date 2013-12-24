package Pye;

# ABSTRACT: Session-based logging platform on top of MongoDB

use warnings;
use strict;
use version;

use Carp;
use MongoDB;
use MongoDB::Code;
use Tie::IxHash;

our $VERSION = "1.000000";
$VERSION = eval $VERSION;

my $now = MongoDB::Code->new(code => 'function() { return new Date() }');

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

=head1 CONSTRUCTOR

=head2 new( [ %opts ] )

Creates a new instance of this class. C<%opts> is anything that can be
passed to L<MongoDB::MongoClient> to initiate a database connection, plus
the following options:

=over

=item * B<log_db>

The name of the database to use for saving log messages. Defaults to "logs".

=item * B<log_coll>

The name of the collection in which to save the messages. Defaults to "logs" too.

=item * B<session_coll>

The name of the collection in which to save session info. Defaults to "sessions".

=item * B<be_safe>

Boolean indicating whether inserts should be safe (see L<MongoDB::Collection/"insert ($object, $options?)">
for more info). Defaults to a false value.

=back

=cut

sub new {
	my ($class, %opts) = @_;

	my $db_name = delete($opts{log_db}) || 'logs';
	my $lcoll_name = delete($opts{log_coll}) || 'logs';
	my $scoll_name = delete($opts{session_coll}) || 'sessions';
	my $safety = delete($opts{be_safe}) || 0;

	# use the appropriate mongodb connection class
	# depending on the version of the MongoDB driver
	# installed
	my $conn = version->parse($MongoDB::VERSION) >= v0.502.0 ?
		MongoDB::MongoClient->new(%opts) :
			MongoDB::Connection->new(%opts);

	my $db = $conn->get_database($db_name);
	my $lcoll = $db->get_collection($lcoll_name);
	my $scoll = $db->get_collection($scoll_name);

	$lcoll->ensure_index({ session_id => 1 });
	$scoll->ensure_index({ date => -1 });

	return bless {
		db => $db,
		lcoll => $lcoll,
		scoll => $scoll,
		safety => $safety
	}, $class;
}

=head1 OBJECT METHODS

=head2 log( $session_id, $text, [ \%data ] )

Inserts a new log message to the database, for the session with the supplied
ID and with the supplied text. Optionally, a hash-ref of supporting data can
be attached to the message.

You should note that for consistency, the session ID will always be stored in
the database as a string, even if it's a number.

If a data hash-ref has been supplied, C<Pye> will make sure (recursively)
that no keys of that hash-ref have dots in them, since MongoDB will refuse to
store such hashes. All dots found will be replaced with semicolons (";").

=cut

sub log {
	my ($self, $sid, $text, $data) = @_;

	my $date = $self->{db}->eval($now);

	$self->{scoll}->insert({ _id => "$sid", date => $date })
		unless $self->{scoll}->find_one({ _id => "$sid" });

	my $doc = Tie::IxHash->new(
		session_id => "$sid",
		date => $date,
		text => $text,
	);

	if ($data) {
		# make sure there are no dots in any hash keys,
		# as mongodb cannot accept this
		$doc->Push(data => $self->_remove_dots($data));
	}

	$self->{lcoll}->insert($doc, { safe => $self->{safety} });
}

=head2 session_log( $session_id )

Returns all log messages for the supplied session ID, sorted by date in ascending
order.

=cut

sub session_log {
	my ($self, $session_id) = @_;

	$self->{lcoll}->find({ session_id => "$session_id" })->sort({ date => 1 })->all;
}

=head2 list_sessions( [ \%opts ] )

Returns a list of sessions, sorted by the date of the first message logged for each
session in descending order. If no options are provided, the latest 10 sessions are
returned. The following options are allowed:

=over

=item * B<limit>

How many sessions to list, defaults to 10.

=item * B<query>

A MongoDB query hash-ref to filter the sessions. Defaults to an empty query. You can
query on the session ID (in the C<_id> attribute) and the date (in the C<date> attribute).

=item * B<sort>

A MongoDB sort hash-ref to sort the results. Defaults to C<< { date => -1 } >> so that
sessions are sorted by date in descending order.

=back

=cut

sub list_sessions {
	my ($self, $opts) = @_;

	$opts			||= {};
	$opts->{limit}	||= 10;
	$opts->{query}	||= {};
	$opts->{sort}	||= { date => -1 };

	return $self->{scoll}->find($opts->{query})->sort($opts->{sort})->limit($opts->{limit})->all;
}

###################################
# _remove_dots( \%data )          #
#=================================#
# replaces dots in the hash-ref's #
# keys with semicolons, so that   #
# mongodb won't complain about it #
###################################

sub _remove_dots {
	my ($self, $data) = @_;

	if (ref $data eq 'HASH') {
		my %data;
		foreach (keys %$data) {
			my $new = $_;
			$new =~ s/\./;/g;

			if (ref $data->{$_} && ref $data->{$_} eq 'HASH') {
				$data{$new} = $self->_remove_dots($data->{$_});
			} else {
				$data{$new} = $data->{$_};
			}
		}
		return \%data;
	} elsif (ref $data eq 'ARRAY') {
		my @data;
		foreach (@$data) {
			push(@data, $self->_remove_dots($_));
		}
		return \@data;
	} else {
		return $data;
	}
}

#####################################
# _remove_session_logs($session_id) #
#===================================#
# removes all log messages for the  #
# supplied session ID.              #
#####################################

sub _remove_session_logs {
	my ($self, $session_id) = @_;

	$self->{lcoll}->remove({ session_id => "$session_id" }, { safe => $self->{safety} });
	$self->{scoll}->remove({ _id => "$session_id" }, { safe => $self->{safety} });
}

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
 
Copyright (c) 2013, Ido Perlmuter C<< ido@ido50.net >>.
 
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
