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

subtest 'basic transfer' => sub {
   my $transfer;
   lives_ok {
      $transfer = $ak->transfer_record(
         src         => 3,
         dst         => 4,
         amount      => 1000,
         title       => 'the title',
         description => 'the description',
      );
   } ## end lives_ok
   'ids for all';

   isa_ok $transfer, 'Accounting::Kitty::Result::Transfer';
   is $transfer->src()->id(), 3, 'src id';
   is $transfer->dst()->id(), 4, 'dst id';
   is $transfer->amount(), 1000, 'amount';
   ok !$transfer->is_inverted(), 'output transfer is not inverted';
   is $transfer->title(),       'the title',       'title';
   is $transfer->description(), 'the description', 'description';
   is $transfer->parent_id(), $transfer->id(), 'auto-parenting';
};

subtest 'transfer with negative amount (inversion)' => sub {
   my $transfer;
   lives_ok {
      $transfer = $ak->transfer_record(
         src         => 3,
         dst         => 4,
         amount      => -1000,
         title       => 'the title 2',
         description => 'the description 2',
      );
   } ## end lives_ok
   'ids for all, negative amount';

   isa_ok $transfer, 'Accounting::Kitty::Result::Transfer';
   is $transfer->src()->id(), 3, 'src id';
   is $transfer->dst()->id(), 4, 'dst id';
   is $transfer->amount(), -1000, 'amount';
   ok $transfer->is_inverted(), 'output transfer is inverted';

   my $check = $ak->fetch(Transfer => $transfer->id());
   is $check->id(), $transfer->id(), 'got again same transfer';
   is $check->amount(), 1000, 'same transfer comes with positive amount';
   is $check->src()->id(), 4, 'src id of real transfer';
   is $check->dst()->id(), 3, 'dst id of real transfer';
   ok !$check->is_inverted(), 'real transfer comes not inverted';
};

subtest 'transfer with src object and dst id' => sub {
   my $transfer;
   my $foo = $ak->fetch(Account => {name => 'Foo'});
   lives_ok {
      $transfer = $ak->transfer_record(
         src    => $foo,
         dst    => 4,
         amount => 1000,
         title  => 'the title 3',
      );
   } ## end lives_ok
   'mixed object and id, no description';

   isa_ok $transfer, 'Accounting::Kitty::Result::Transfer';
   is $transfer->src()->id(), 3, 'src id';
   is $transfer->dst()->id(), 4, 'dst id';
   is $transfer->amount(), 1000, 'amount';
   ok !$transfer->is_inverted(), 'output transfer is not inverted';
   is $transfer->title(),       'the title 3', 'title';
   is $transfer->description(), '',            'description (empty)';
   is $transfer->parent_id(), $transfer->id(), 'auto-parenting';
};

subtest 'modifications on affected accounts and owners' => sub {
   my ($foo, $bar) = $ak->fetch(
      Account => 3,
      Account => {name => 'Bar'},
   );
   is $foo->total(), -7000, 'Foo account total';
   is $bar->total(), 7000,  'Bar account total';
   is $foo->owner()->total(), -7000, 'FooOwner owner total';
   is $bar->owner()->total(), 7000,  'BarOwner owner total';
};

done_testing();
