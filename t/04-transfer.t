use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty()
  or BAIL_OUT 'no testing without an Accounting::Kitty object';
isa_ok $ak, $_ for qw< Accounting::Kitty DBIx::Class::Schema >;

TestLib::populate($ak);

my $transfer;
subtest 'fetch transfer' => sub {
   lives_ok { $transfer = $ak->fetch(Transfer => 1) } 'fetch transfer';
   isa_ok $transfer, 'Accounting::Kitty::Result::Transfer';
   is $transfer->id(),          1,             'id';
   is $transfer->amount(),      1000,          'amount';
   is $transfer->title(),       'titolo',      'title';
   is $transfer->description(), 'descrizione', 'description';

   my $date = $transfer->date();
   isa_ok $date, 'DateTime';
   is $date->epoch(), 1234567890, "date";

   is $transfer->src()->name(), 'External', 'src (External)';
   is $transfer->dst()->name(), 'Common',   'dst (Common)';
   ok !$transfer->is_inverted(), 'transfer is not inverted';
};

subtest 'transfer inversion' => sub {
   ok !$transfer->is_inverted(), 'transfer is not inverted';
   $transfer->invert();
   ok $transfer->is_inverted(), 'transfer is inverted now';

   is $transfer->amount(), -1000, 'amount is inverted';
   is $transfer->src()->name(), 'Common',   'src is inverted';
   is $transfer->dst()->name(), 'External', 'dst is inverted';
};

subtest 'change transfer' => sub {
   $transfer->amount(-2000);
   $transfer->update();
   ok $transfer->is_inverted(), 'transfer still inverted after update';
   is $transfer->amount(), -2000, 'amount is updated and still inverted';
   is $transfer->src()->name(), 'Common',   'src is still inverted';
   is $transfer->dst()->name(), 'External', 'dst is still inverted';

   # get a new fresh, non-inverted copy
   my $alter = $ak->fetch(Transfer => 1);
   is $alter->amount(), 2000, 'amount changed correctly';
   is $alter->src()->name(), 'External', 'same source';
   is $alter->dst()->name(), 'Common',   'same destination';

   $alter->amount(3000);
   $alter->update();

   ok $transfer->is_inverted(),
     'transfer still inverted after alter update';
   is $transfer->amount(), -2000, 'amount still holds old value though';
   $transfer->discard_changes();
   ok $transfer->is_inverted(),
     'transfer still inverted after discard_changes';
   is $transfer->amount(), -3000, 'amount now has updated value';
};

my $common = $transfer->dst();
subtest 're-get transfer, starting from Common now' => sub {
   my ($alter, @rest);
   lives_ok { ($alter, @rest) = $common->transfers() }
   'retrieve list of transfers (from Common)';
   is scalar(@rest), 0, 'no other transfer for Common too';
   isa_ok $alter, 'Accounting::Kitty::Result::Transfer';
   is $alter->id(),     1,    'id';
   is $alter->amount(), 3000, 'amount';
   ok !$alter->is_inverted(), 'transfer is not inverted';
};

done_testing();

