use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

subtest 'simple transfer_delete' => sub {
   my $ak = TestLib::kitty(populate => 1);

   my $transfer = $ak->fetch(Transfer => 1);
   my $amount = $transfer->amount();
   is $amount, 1000, 'initial transfer amount as expected';

   my @parties = ($transfer->src(), $transfer->dst());
   my ($ssrc, $sdst) = map { $_->total() } @parties;

   lives_ok { $ak->transfer_delete(1) } 'transfer_delete lives';

   my $post_transfer = $ak->fetch(Transfer => 1);
   my ($esrc, $edst) = map { $_->discard_changes(); $_->total() } @parties;

   is(($ssrc + $amount), $esrc, 'src got resources back');
   is(($sdst - $amount), $edst, 'dst gave resources back');
};

subtest 'remove child transfer' => sub {
   my $ak = TestLib::kitty(populate => 1);

   my @transfers =
     $ak->fetch(Transfer => {parent_id => 3, is_deleted => undef});
   is scalar(@transfers), 3, 'three transfers in group 3';

   my ($transfer) = grep { $_->id() == 4 } @transfers;
   ok $transfer, 'one of them has id 4';

   lives_ok { $ak->transfer_delete($transfer) } 'transfer_delete lives';

   @transfers = $ak->fetch(
      Transfer => {
         parent_id  => 3,
         is_deleted => undef, # look for stuff that's still alive!
      }
   );
   is scalar(@transfers), 1, 'one transfer left in group 3 (the leader)';
};

subtest 'remove parent transfer' => sub {
   my $ak = TestLib::kitty(populate => 1);

   my @transfers =
     $ak->fetch(Transfer => {parent_id => 3, is_deleted => undef});
   is scalar(@transfers), 3, 'three transfers in group 3';

   my ($transfer) = grep { $_->id() == 3 } @transfers;
   ok $transfer, 'one of them has id 3 (the leader)';

   lives_ok { $ak->transfer_delete($transfer) } 'transfer_delete lives';

   @transfers = $ak->fetch(
      Transfer => {
         parent_id  => 3,
         is_deleted => undef, # look for stuff that's still alive!
      }
   );
   is scalar(@transfers), 0, 'no transfer left in group 3';
};

done_testing();
