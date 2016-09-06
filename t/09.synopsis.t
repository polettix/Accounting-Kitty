use strict;
use Test::More;
use Test::Exception;
use 5.010;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty();    # in-memory, no populate, auto-create tables

my $owner_rs  = $ak->resultset('Owner');
my $foo_owner = $owner_rs->create({key => 'FooOwner'});
my $bar_owner = $owner_rs->create({key => 'BarOwner'});

is $ak->fetch(Owner => {key => 'FooOwner'})->id(), $foo_owner->id(),
  'one owner in the DB';

my $project_rs = $ak->resultset('Project');
my $house_prj  = $project_rs->create({name => 'house'});
my $v2016_prj  = $project_rs->create({name => 'vacation 2016'});

my $account_rs = $ak->resultset('Account');
my $wife       = $account_rs->create(
   {
      owner   => $foo_owner,
      project => $house_prj,
      name    => 'Wife',
      total   => 5000,
   }
);
my $husband = $account_rs->create(
   {
      owner   => $bar_owner,
      project => $house_prj,
      name    => 'Husband',
      total   => 5000,
   }
);
$account_rs->create(
   {    # NOTE: NO OWNER HERE!
      project => $house_prj,
      name    => 'External',
      total   => -10000,
   }
);
my $common = $account_rs->create(
   {    # NOTE: NO OWNER HERE!
      project => $house_prj,
      name    => 'Common',
      total   => 0,
   }
);

# make sure we reload all stuff from DB
$_->discard_changes() for ($wife, $husband, $common);

my $quota_rs = $ak->resultset('Quota');

# the following quotas have the same name so the weights go
# together. To split equally, we set the same weight; we might
# as well set both to 50, or 100, or whatever positive integer
$quota_rs->create(
   {
      name    => 'fifty-fifty',
      account => $wife,
      weight  => 1,
   }
);
$quota_rs->create(
   {
      name    => 'fifty-fifty',
      account => $husband,
      weight  => 1,
   }
);

# the following quotas have different names so they are
# separated
$quota_rs->create(
   {
      name    => '100% Wife',
      account => $wife,
      weight  => 1,             # whatever weight is fine
   }
);
$quota_rs->create(
   {
      name    => '100% Husband',
      account => $husband,
      weight  => 1,                # whatever weight is fine
   }
);

my @quotas = $quota_rs->all();
is scalar(@quotas), 4, 'four quotas in DB';

# start transferring resources around, one transfer
my $t1 = $ak->create_transfer(
   src    => {name => 'External'},
   dst    => {name => 'Common'},
   amount => 10000, # stick to integers
   title  => 'donation from a rich uncle',
);
$t1->discard_changes();            # to be on the safe side
is $t1->id(),     1,     'id of first transfer';
is $t1->amount(), 10000, 'amount of first transfer';

# make sure we reload all stuff from DB
$_->discard_changes() for ($wife, $husband, $common);
is $common->total(),  10000, 'new resources to distribute!';
is $wife->total(),    5000,  'Wife still there';
is $husband->total(), 5000,  'Husband still there';

# distribute it, returns all distribution transfers back
my @dt1 = $ak->distribution_split(
   transfer => $t1,
   quotas   => 'fifty-fifty',    # subject to change
);
is scalar(@dt1), 2, 'two transfers in fifty-fifty division';

# make sure we reload all stuff from DB
$_->discard_changes() for ($wife, $husband, $common);
is $common->total(),  0,     'resources distributed!';
is $wife->total(),    10000, 'Wife got half';
is $husband->total(), 10000, 'Husband got other half';

# these transfers go together or fail together. The result is
# quite similar to the transfer and distribution above, except
# for the parts (Wife gets more here!)
my @closeby = $ak->multi_transfers_record(
   {
      src    => {name => 'External'},
      dst    => $common,
      title  => 'prova (main)',
      amount => 10000,
   },
   {
      src    => $common,
      dst    => $wife,
      title  => 'prova (first)',
      amount => 7000,
      parent => '[0]',             # refers to the first transfer in list
   },
   {
      src    => $common,
      dst    => $husband,
      title  => 'prova (second)',
      amount => 3000,
      parent => '[0]',              # refest to the first transfer in list
   },
);
is scalar(@closeby), 3, 'three transfers in multi-transfers record';

# make sure we reload all stuff from DB
$_->discard_changes() for ($wife, $husband, $common);
is $common->total(),  0,     'resources distributed on the fly!';
is $wife->total(),    17000, 'Wife got some';
is $husband->total(), 13000, 'Husband got the rest';

# of course if you want to take advantage of quotas you can do
# this atomically too. Here the Husband takes more, otherwise it's
# equivalent to the calls above
my @transfers = $ak->transfer_and_distribution_split(
   {    # this is the transfer
      src    => {name => 'External'},
      dst    => $common,
      title  => 'prova (main)',
      amount => 10000,
   },
   {    # this is the distribution split
      quotas => [
         {
            account => $wife,
            amount  => 3000,
         },
         {
            account => $husband,
            amount  => 7000,
         }
      ],
      title => 'prova (distribution)',
   },
);
is scalar(@closeby), 3, 'three transfers in transfer and distribution';

# reload stuff from DB
$_->discard_changes() for ($wife, $husband, $common);
is $common->total(),  0,     'all things were distributed eventually';
is $wife->total(),    20000, 'total for Wife';
is $husband->total(), 20000, 'total for Husband';
is $ak->fetch(Account => {name => 'External'})->total(), -40000,
  'zero-sum!';

done_testing();
