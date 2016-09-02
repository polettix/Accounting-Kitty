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
      @transfers = $ak->transfer_and_contribution_split(
         { # this is the transfer
            src    => 1,
            dst    => 2,
            title  => 'prova (main)',
            amount => 10000,
         },
         { # this is the contribution split
            quotas => [
               {
                  account => 3,
                  amount => 7000,
               },
               {
                  account => 4,
                  amount => 3000,
               }
            ],
            title  => 'prova (distribution)',
         },
      );
   } ## end lives_ok
   'transfer_and_contribution_split lives';

   is scalar(@transfers), 3, 'three transfers created';

   is $_->parent()->id(), $transfers[0]->id(), 'first transfer is parent'
     for @transfers;

};

done_testing();

