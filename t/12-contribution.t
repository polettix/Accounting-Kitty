use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

subtest 'simple transfer_delete' => sub {
   my $ak = TestLib::kitty(populate => 1);

   lives_ok {
      $ak->transfer_contribution_split(
         transfer => 1,
         quotas => [{account_id => 3, amount => 700,}, {account_id => 4, amount => 300,},]
      );
   } ## end lives_ok
   'transfer_contribution_split lives';
};

done_testing();
