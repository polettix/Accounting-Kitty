use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty()
  or BAIL_OUT 'no testing without an Accounting::Kitty object';
TestLib::populate($ak);

my $external;
lives_ok { $external = $ak->fetch(Account => 1) } 'fetch account';
isa_ok $external, 'Accounting::Kitty::Result::Account';

subtest 'basic characteristics of the account External' => sub {
   is $external->id(),    1,          'id';
   is $external->name(),  'External', 'name';
   is $external->data(),  'service',  'data';
   is $external->total(), -1000,      'total';
};

my $transfer;
subtest 'list of (one) transfer' => sub {
   my @rest;
   lives_ok { ($transfer, @rest) = $external->transfers() }
   'retrieve list of transfers';
   is scalar(@rest), 0, 'no other transfers present';
   isa_ok $transfer, 'Accounting::Kitty::Result::Transfer';
   is $transfer->id(), 1, 'id';

   my $src;
   lives_ok { $src = $transfer->src(); } 'get src account from transfer';
   isa_ok $src, 'Accounting::Kitty::Result::Account';
   is $src->id(), 1, 'src id';

   my $dst;
   lives_ok { $dst = $transfer->dst(); } 'get dst account from transfer';
   isa_ok $dst, 'Accounting::Kitty::Result::Account';
   is $dst->id(), 2, 'dst id';
};

subtest 're-get transfer, starting from account Common now' => sub {
   my $common = $ak->fetch(Account => 2);

   my ($alter, @rest);
   lives_ok { ($alter, @rest) = $common->transfers() }
   'retrieve list of transfers (from Common)';
   is scalar(@rest), 0, 'no other transfer for Common too';
   isa_ok $alter, 'Accounting::Kitty::Result::Transfer';
   is $alter->id(),     1,    'id';
   is $alter->amount(), 1000, 'amount';
   ok !$transfer->is_inverted(), 'transfer is not inverted';
};

subtest 'owner' => sub {
   my $owner;
   lives_ok { $owner = $external->owner() } 'get owner';
   is $owner, undef, 'no owner for External';

   my $foo = $ak->fetch(Account => {name => 'Foo'});
   $owner = $foo->owner();
   isa_ok $owner, 'Accounting::Kitty::Result::Owner';
   is $owner->id(), 1, 'owner id';
};

subtest 'project' => sub {
   my $project;
   lives_ok { $project = $external->project() } 'get project';
   isa_ok $project, 'Accounting::Kitty::Result::Project';
   is $project->id(), 1, 'project id';
};

done_testing();
