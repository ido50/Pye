package Pye;

# ABSTRACT: Session-based logging platform on top of MongoDB

use warnings;
use strict;
use version;

use Carp;
use DateTime;
use MongoDB;
use MongoDB::Code;
use Tie::IxHash;

our $VERSION = "1.000000";
$VERSION = eval $VERSION;

my $now = MongoDB::Code->new(code => 'function() { return new Date() }');

sub new {
	my ($class, %opts) = @_;

	my $db_name = delete($opts{log_db}) || 'logs';
	my $coll_name = delete($opts{log_coll}) || 'logs';

	# use the appropriate mongodb connection class
	# depending on the version of the MongoDB driver
	# installed
	my $conn = version->parse($MongoDB::VERSION) >= v0.502.0 ?
		MongoDB::MongoClient->new(%opts) :
			MongoDB::Connection->new(%opts);

	my $db = $conn->get_database($db_name);

	return bless {
		db => $db,
		coll => $db->get_collection($coll_name)
	}, $class;
}

sub log {
	my ($self, $sid, $text, $data) = @_;

	my $doc = Tie::IxHash->new(
		session_id => $sid,
		date => $self->{db}->eval($now),
		text => $text,
	);

	if ($data) {
		# make sure there are no dots in any hash keys,
		# as mongodb cannot accept this
		$doc->Push(data => $self->_remove_dots($data));
	}

	$self->{coll}->insert($doc);
}

sub find_by_session {
	my ($self, $session_id) = @_;

	$self->{coll}->find({
		session_id => { '$in' => [''.$session_id, int($session_id)] }
	})->sort({ date => 1 })->all;
}

sub latest_sessions {
	my ($self, $limit) = @_;

	$limit ||= 10;

	my $map = 'function() {
		emit(this.session_id, this.date);
	}';

	my $reduce = 'function(key, current) {
		var smallest;
		for (var i = 0; i < current.length; i++) {
			var doc = current[i];
			if (!smallest || doc < smallest)
				smallest = doc;
		}
		return smallest;
	}';

	return reverse sort { $a->{value} cmp $b->{value} } @{$self->{db}->run_command([
		'mapreduce' => $self->{coll}->name,
		'map' => $map,
		'reduce' => $reduce,
		'out' => { inline => 1 },
	])->{results}};
}

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

=head1 NAME

Pye - Session-based logging platform on top of MongoDB

=head1 SYNOPSIS

	use Pye;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.

=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.

=cut



# ---
# ---
# Module implementation here
# ---
# ---

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back

=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
MLog requires no configuration files or environment variables.

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.

=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-MLog@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MLog>.

=head1 AUTHOR

Ido Perlmuter <idope@bezeq.co.il>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2013 by Bezeq Inc..  No
license is granted to other entities.


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
