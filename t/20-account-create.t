use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty(populate => 1);

subtest 'account creation' => sub {
   my $account;
   lives_ok {
      $account = $ak->create_account(
         {
            project => 3,
            owner   => 2,
            name    => 'Busto',
            data    => 'whatever',
            total   => 0,
         }
      );
   } ## end lives_ok
   'account creation lives';

   my $created = $ak->fetch(Account => $account->id());
   ok $created, 'retrieved created account';

   is $created->name(),  'Busto',    'name';
   is $created->data(),  'whatever', 'data';
   is $created->total(), 0,          'total';

   is $created->project()->name(), 'BazProject3', 'name of project';
   is $created->owner()->key(),    'BarOwner',    'key of owner';
};

subtest 'account creation, with objects' => sub {
   my $owner = $ak->fetch(Owner => 2);
   my $project = $ak->fetch(Project => 3);
   my $account;
   lives_ok {
      $account = $ak->create_account(
         {
            project => $project,
            owner   => $owner,
            name       => 'Busto',
            data       => 'whatever',
            total      => 0,
         }
      );
   } ## end lives_ok
   'account creation lives';

   my $created = $ak->fetch(Account => $account->id());
   ok $created, 'retrieved created account';

   is $created->name(),  'Busto',    'name';
   is $created->data(),  'whatever', 'data';
   is $created->total(), 0,          'total';

   is $created->project()->name(), 'BazProject3', 'name of project';
   is $created->owner()->key(),    'BarOwner',    'key of owner';
};

subtest 'account creation failure' => sub {
   throws_ok {
      $ak->create_account(
         {
            project => 30,
            owner   => 2,
            name    => 'Busto',
            data    => 'whatever',
            total   => 0,
         }
      );
   } qr{(?i:invalid project)}, 'cannot create without valid project id';
};

done_testing();
