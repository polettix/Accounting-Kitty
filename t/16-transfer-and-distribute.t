use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

subtest 'distribution' => sub {
   my $ak = TestLib::kitty(populate => 1);

   my @transfers;
   lives_ok {
      @transfers = $ak->transfer_and_distribution_split(
         {    # this is the transfer
            src    => 1,
            dst    => 2,
            title  => 'prova (main)',
            amount => 10000,
         },
         {    # this is the contribution split
            quotas => [
               {
                  account => 3,
                  amount  => 7000,
               },
               {
                  account => 4,
                  amount  => 3000,
               }
            ],
            title => 'prova (distribution)',
         },
      );
   } ## end lives_ok
   'transfer_and_contribution_split lives';

   is scalar(@transfers), 3, 'three transfers created';

   is $_->parent()->id(), $transfers[0]->id(), 'first transfer is parent'
     for @transfers;

   my %account = (
      1 => -11000,
      2 => 1000,     # unchanged!
      3 => 1000,
      4 => 9000,
   );
   while (my ($id, $total) = each %account) {
      is $ak->fetch(Account => $id)->total(), $total, "account no. $id";
   }

   is $ak->fetch(Owner => 1)->total(), 1000, 'owner no. 1';
   is $ak->fetch(Owner => 2)->total(), 9000, 'owner no. 2';
};

done_testing();
