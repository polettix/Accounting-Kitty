use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

subtest 'contribution' => sub {
   my $ak = TestLib::kitty(populate => 1);

   my @transfers = $ak->fetch(Transfer => {parent_id => 1});
   is scalar(@transfers), 1, 'one transfers under parent 1 now';

   my $foo = $ak->fetch(Account => 3);
   my $sfoo = $foo->total();

   lives_ok {
      $ak->contribution_split(
         transfer => 1,
         quotas   => [
            {account => 3, amount => 700,},
            {account => 4, amount => 300,},
         ]
      );
   } ## end lives_ok
   'contribution_split lives';

   @transfers = $ak->fetch(Transfer => {parent_id => 1});
   is scalar(@transfers), 3, 'three transfers under parent 1 now';

   my ($transfer) = grep { $_->src()->id() == 3 } @transfers;
   ok $transfer, 'one transfer has src account 3';
   is $transfer->amount(), 700, 'amount of one sub-transfer';
   isnt $transfer->id(), $transfer->parent(),
     'sub-transfer is proper child';

   $foo->discard_changes();
   my $efoo = $foo->total();
   is int($sfoo - 700), $efoo, 'account no. 3 decremented as expected';
   is $efoo, -6700, 'double check on previous statement';

   is $ak->fetch(Account => 1)->total(), 0,
     'account no. 1 increased as expected';

   is $ak->fetch(Owner => 1)->total, -6700, 'owner updated too';
};

done_testing();
