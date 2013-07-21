#!perl -T

use warnings;
use strict;
use Test::More tests => 3;
use Pye;

my $pye = Pye->new;

ok($pye, "Pye object created");

ok($pye->log(1, "What's up?"), "GOOD");

ok($pye->log(1, "Some data", { hey => 'there' }), "VERY GOOD");

done_testing();
