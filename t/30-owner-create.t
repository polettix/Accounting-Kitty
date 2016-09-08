use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty(populate => 1);

subtest 'owner creation' => sub {
   my $owner;
   lives_ok {
      $owner = $ak->create_owner(
         {
            key   => 'Busto',
            data  => 'whatever',
            total => 10,
         }
      );
   } ## end lives_ok
   'account creation lives';

   my $created = $ak->fetch(Owner => $owner->id());
   ok $created, 'retrieved created owner';

   is $created->key(),   'Busto',    'key';
   is $created->data(),  'whatever', 'data';
   is $created->total(), 10,         'total';
};

subtest 'owner creation failure' => sub {
   throws_ok {
      $ak->create_owner({});
   }
   qr{(?i:invalid owner key: undefined)},
     'cannot create without valid key';
};

subtest 'owner creation failure, duplicate key' => sub {
   throws_ok {
      $ak->create_owner(
         {
            key   => 'Busto',
            data  => 'whatever',
            total => 10,
         }
      );
   }
   qr{(?i:Invalid owner key, already present)},
     'cannot create without valid key';
};

done_testing();
