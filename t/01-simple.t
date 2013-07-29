#!perl -T

use warnings;
use strict;
use Test::More tests => 7;
use Pye;

my $pye = Pye->new;

ok($pye, "Pye object created");

ok($pye->log(1, "What's up?"), "Simple log message");

ok($pye->log(1, "Some data", { hey => 'there' }), "Log message with data structure");

my @latest_sessions = $pye->latest_sessions;

is(scalar(@latest_sessions), 1, "We only have one session");

is($latest_sessions[0]->{_id}, '1', "We have the correct session ID");

my @logs = $pye->find_by_session(1);

is(scalar(@logs), 2, 'Session has two log messages');

ok(exists $logs[1]->{data} && $logs[1]->{data}->{hey} eq 'there', 'Second log message has a data element');

#$pye->_remove_session_logs(1);

done_testing();
