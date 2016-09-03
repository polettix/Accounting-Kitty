# NAME

Accounting::Kitty - Simple accounting system for a shared fund

# VERSION

This document describes Accounting::Kitty version {{\[ version \]}}.

# SYNOPSIS

    use Accounting::Kitty;

    # it's based on DBIx::Class... so you have connect() instead
    # of new()...
    my $ak = Accounting::Kitty->connect(@DBI_params);

    # if you stick with SQLite, you can auto-create tables
    $ak->initialize_tables();

    # it's not a tutorial on DBIx::Class, but you can get started
    # like this
    my $owner_rs = $ak->resultset('Owner');
    my $foo_owner = $owner_rs->create({ key => 'FooOwner' });
    my $bar_owner = $owner_rs->create({ key => 'BarOwner' });

    my $project_rs = $ak->resultset('Project');
    my $house_prj = $project_rs->create({ name => 'house' });
    my $v2016_prj = $project_rs->create({ name => 'vacation 2016' });

    my $account_rs = $ak->resultset('Account');
    my $wife = $account_rs->create({
       owner => $foo_owner,
       project => $house_prj,
       name => 'Wife',
       total => 5000,
    });
    my $husband = $account_rs->create({
       owner => $bar_owner,
       project => $house_prj,
       name => 'Husband',
       total => 5000,
    });
    $account_rs->create({      # NOTE: NO OWNER HERE!
       project => $house_prj,
       name => 'External',
       total => -10000,
    });
    my $common = $account_rs->create({      # NOTE: NO OWNER HERE!
       project => $house_prj,
       name => 'Common',
       total => 0,
    });

    # make sure we reload all stuff from DB
    $_->discard_changes() for ($wife, $husband, $common);

    # time to add some quotas
    my $quota_rs = $ak->resultset('Quota');

    # the following quotas have the same name so the weights go
    # together. To split equally, we set the same weight; we might
    # as well set both to 50, or 100, or whatever positive integer
    $quota_rs->create({
       name => 'fifty-fifty',
       account => $wife,
       value => 1,
    });
    $quota_rs->create({
       name => 'fifty-fifty',
       account => $husband,
       value => 1,
    });

    # the following quotas have different names so they are
    # separated
    $quota_rs->create({
       name => '100% Wife',
       account => $wife,
       value => 1,            # whatever weight is fine
    });
    $quota_rs->create({
       name => '100% Husband',
       account => $husband,
       value => 1,            # whatever weight is fine
    });

    # you can retrieve stuff by id, name or whatever query is
    # supported in the DBIx::Class system
    my ($wife, $husband, $owner1) = $ak->fetch(
       Account => 1,                    # same as {id => 1}
       Account => {name => 'Husband'},
       Owner   => {key => 'FooOwner'},
    );

    # start transferring resources around, one transfer
    my $t1 = $ak->transfer_record(
       src => {name => 'External'},
       dst => {name => 'Common'},
       amount => 10000,            # stick to integers
       title  => 'donation from a rich uncle',
    );

    # distribute it, returns all distribution transfers back
    my @dt1 = $ak->distribution_split(
       transfer => $t1,
       quotas => 'fifty-fifty', # subject to change
    );

    # these transfers go together or fail together. The result is
    # quite similar to the transfer and distribution above, except
    # for the parts (Wife gets more here!)
    my @closeby = $ak->multi_transfers_record(
       {
          src    => { name => 'External' },
          dst    => $common,
          title  => 'prova (main)',
          amount => 10000,
       },
       {
          src    => $common,
          dst    => $wife,
          title  => 'prova (first)',
          amount => 7000,
          parent => '[0]',  # refers to the first transfer in list
       },
       {
          src    => $common,
          dst    => $husband,
          title  => 'prova (second)',
          amount => 3000,
          parent => '[0]',  # refest to the first transfer in list
       },
    );

    # of course if you want to take advantage of quotas you can do
    # this atomically too. Here the Husband takes more, otherwise it's
    # equivalent to the calls above
    my @transfers = $ak->transfer_and_distribution_split(
       {    # this is the transfer
          src    => { name => 'External' },
          dst    => $common,
          title  => 'prova (main)',
          amount => 10000,
       },
       {    # this is the contribution split
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

# DESCRIPTION

This module allows you to manage a simple shared fund of money (or
whatever other resource you can count). It main purpose is to track how
much of a total amount belongs to each participant in the fund, allowing
you to perform operations like adding or subtracting from the fund.

The basic working is that of a double entry system: every transaction
always involves two parties. It's possible to handle multiparty
transactions too, but they always resolve to be man two-party
transactions actually. In its current state, it allows to easily track
expenses that should be split across multiple participants, possibly
according to a given preset scheme (e.g. equal split, or weighted, or
based on a table that varies in time).

## Transfer Splitting

A transfer can be split into component parts, e.g. a common expense
might be split across multiple participant accounts.

A split can be either a _contribution_ or a _distribution_, depending
on how resources are flowing. In a _contribution_, you're splitting the
original transfer across multiple sources, which will see their
resources decremented (to "participate" in the transfer); in a
_distribution_, instead, the original transfer is split across multiple
destinations, increasing their resources.

To generate transfers for a split, use ["contribution\_split"](#contribution_split) and
["distribution\_split"](#distribution_split). They have the same interface, accepting a hash
reference `\%def` with the following keys:

- `date`

    the split transaction(s) date (and time), parsed via
    ["parse\_datetime" in DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime::Format::ISO8601#parse_datetime). Defaults to
    the split transfer date;

- `description`

    a string with the description of the split transaction(s), optional
    (defaults to the split transfer description);

- `exact`

    flag if the `quota_type` has to be assumed to hold _exact_ values,
    i.e. if they have not to be interpreted as _weights_. Defaults to a
    false value, which means that quota elements are usually interpreted as
    weights;

- `quota_type`

    an indication of how to split the input transfer into sub-transfers. See
    ["Quotas"](#quotas) for details;

- `title`

    a string with the title of the split transaction(s), optional (defaults
    to the split transfer title);

- `transfer`

    the transaction to be split.

## Quotas

In ["contribution\_split"](#contribution_split) and ["distribution\_split"](#distribution_split), there are a few
ways in which you can divide a transfer into _quotas_ (via parameter
["quota\_type"](#quota_type)), depending on the flexibility level that you need.

The most flexible way is to pass an array reference containing hashes
with the following fields:

- `account`

    the account participating in the split with the specific quota;

- `amount`

    the exact amount for the quota;

- `weight`

If the first item contains `amount`, all of them MUST have the same key
too and an exact split will be performed, using those amounts.
Otherwise, all items MUST contain `weight`, and these weights will be
used to split the provided amount into splits according to their values.

In addition to this, which requires you to do all the work of either
figuring out the right amounts, or at least determine the weights, there
are also two additional possibilities: using pre-defined fixed quota
weights and using _finance_ splitting weights. These are described
in the following sub-sections.

### Fixed Quota Groups

In fixed quota groups, you refer to a configuration of fixed quotas
inside the database. For example, consider the following case:

    Table: account
    id          name        _type       total     
    ----------  ----------  ----------  ----------
    1           External    service     0         
    2           Common      service     0         
    3           Foo         owned       0
    4           Bar         owned       0

    Table: quota
    id          name         account_id  value     
    ----------  -----------  ----------  ----------
    1           fifty-fifty  3           1
    2           fifty-fifty  4           1
    3           100% Foo     3           1
    4           100% Bar     4           1

There are three quota groups, identified by the name: `fifty-fifty`,
`100% Foo`, `100% Bar`. All weights are set to 1, which means that:

- for `fifty-fifty`, accounts `3` and `4` will split equally (as they
have the same weight);
- for `100% Foo`, account `3` will take it all (there's no other account
to share the split);
- for `100% Bar`, account `4` will take it all (there's no other account
to share the split).

If you are more comfortable you can use percentages, of course:

    Table: quota
    id          name         account_id  value     
    ----------  -----------  ----------  ----------
    1           fifty-fifty  3           50
    2           fifty-fifty  4           50
    3           100% Foo     3           100
    4           100% Bar     4           100

The outcome would be the same (in particular, in the `fifty-fifty` case
both accounts still have the same weight).

### Finance Quota Groups

Finance quota groups are useful for dealing with shared long-term
divisions, like mortgages. As a matter of fact, it's designed around
mortgages where you know in anticipation what capital is going to be
provided by all participants at a given step, but you have to figure out
how to divide the (possibly variable) interest part.

Suppose that Alice and Bob are sharing a payment plan where they are
supposed to give back 10000 (capital) resources in 5 steps of 2000
resources each. They decided to split this capital part as follows, to
cope with Bob's initial difficulties:

    Capital quotas by step

    Step 1    Alice 1500   Bob  500   Total  2000
    Step 2    Alice 1200   Bob  800   Total  2000
    Step 3    Alice 1000   Bob 1000   Total  2000
    Step 4    Alice  800   Bob 1200   Total  2000
    Step 5    Alice  500   Bob 1500   Total  2000
    ---------------------------------------------
    Total     Alice 5000   Bob 5000   Total 10000

They have a variable interest and their invoice at step 2 amounts to
2400 resources. How should they split it?

According to their plan, Alice will provide 1200 resources to cope with
the capital part, and Bob will provide the remaining 800. Now there are
400 resources left, that have to be divided in some fair way between the
two.

To do a fair split of the interest, it's useful to take a look at the
table of residual capital parts at each step:

    Capital residuals at beginnin of the step

    Step 1    Alice 5000   Bob 5000   Total 10000
    Step 2    Alice 3500   Bob 4500   Total  8000
    Step 3    Alice 2300   Bob 3700   Total  6000
    Step 4    Alice 1300   Bob 2700   Total  4000
    Step 5    Alice  500   Bob 1500   Total  2000

At the beginning of step 2, Bob still has to give 4500 resources back,
while Alice owes 3500. These numbers are then used as weights to divide
the 400 interest resources:

    Interest quotas

    Step 2    Alice  175   Bob  225   Total   400

As expected, Bob is paying some more resources of interest for the
privilege of a slower initial payback arrangement. So, quotas for this
second step will be:

    Overall quotas

    Step 2    Alice 1375   Bob 1025   Total  2400

See [QuotaFinance](https://metacpan.org/pod/QuotaFinance) for details on the knobs you have to manage quota
finance groups.

# METHODS

`Accounting::Kitty` inherits from [DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema), so it gets
all its methods (most notably the constructor and `resultset`).

## **accounts**

    my @accounts = $ak->accounts();
    my $accounts = $ak->accounts();
    my @accounts = $ak->accounts(@query);
    my $accounts = $ak->accounts(@query);

retrieve a list of [Accounting::Kitty::Result::Account](https://metacpan.org/pod/Accounting::Kitty::Result::Account) objects.

You can call it either in list context (getting the list of account
objects back) or in scalar context (getting an anonymous array back).

You can optionally pass a `@query` compatible with
["resultset" in DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema#resultset); otherwise, all accounts will be
returned.

## **contribution\_split**

    my @transfers = $ak->contribution_split(\%def);
    my $transfers = $ak->contribution_split(\%def);

split a transfer into contribution parts. Returns the list of generated
transfers or a reference to an array with the list, in scalar context.

See ["Transfer Splitting"](#transfer-splitting) for details on the parameters in the input
hash.

## **distribution\_split**

    my @transfers = $ak->distribution_split(\%def);
    my $transfers = $ak->distribution_split(\%def);

split a transfer into distribution parts. Returns the list of generated
transfers or a reference to an array with the list, in scalar context.

See ["Transfer Splitting"](#transfer-splitting) for details on the parameters in the input
hash.

## **fetch**

    my $item = $ak->fetch($what, $query);
    my @items = $ak->fetch($what1, $query1, ...);

fetch multiple items in a _DWIM_ way.

In scalar context, it only gets one single item based on the first two
parameters. In list context, one item is returned for every pair of
input parameters.

Each item is fetched based on two parameters: an item type `$what` and
a query hint.

The `$what` can be `Account`, `Transfer`, `Quota` and
`QuotaFinance`, corresponding to the different result types managed by
this distribution (if you extend it adding more result classes, you can
fetch them too of course).

The `$query` can be:

- an object, which is passed along unmodified (without checking that it is
of the right class). This allows you to just pass what you have through
`fetch` and avoid checking;
- a plain scalar, regarded as the item's identifier in the relevant
database table;
- a hash reference containing a query that is compatible with
["resultset" in DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema#resultset).

In the following example, we assume that an account exists with id `1`
and name "Foo". All calls to fetch return the same account:

    my $by_id   = $ak->fetch(Account => 1);
    my $by_obj  = $ak->fetch(Account => $by_id);
    my $by_name = $ak->fetch(Account => {name => 'Foo'});

## **initialize\_tables**

    $ak->initialize_tables();

setup initial tables in the database. The schema provided is good for
SQLite, in other DB engines your mileage may vary. Returns nothing.

## **multi\_transfers\_record**

    my @transfers = $ak->multi_transfer_record(@transfers);

record multiple, possibly related, transfers in a single transaction.
Returns the newly created transfers.

Each item in `@transfers` is a hash reference compatible suitable for
["transfer\_record"](#transfer_record). The only exception is that parameter `parent` can
be set to reference elements in `@transfers` that occur _before_ the
specific transfer to be recorded, indicating the parent transfer index
as a string between brackets.

In the following example, we ask the creation of three transfers, the
first one being the parent of the following two. As you can see, the
`parent` key in the child transfers is a string with a `0` in
brackets; the `0` indicates the index of the first transfer in the
provided list (i.e. the `prova (main)` transfer at the beginning).

    @transfers = $ak->multi_transfers_record(
       {
          src    => 1,
          dst    => 2,
          title  => 'prova (main)',
          amount => 10000,
       },
       {
          src    => 2,
          dst    => 3,
          title  => 'prova (first)',
          amount => 7000,
          parent => '[0]',
       },
       {
          src    => 2,
          dst    => 4,
          title  => 'prova (second)',
          amount => 3000,
          parent => '[0]',
       },
    );

## **owners**

    my @owners = $ak->owners();
    my $owners = $ak->owners();

get a list of an array reference with the list of owners.

## **projects**

    my @projects = $ak->projects();
    my $projects = $ak->projects();

get a list of an array reference with the list of projects.

## **quota\_groups**

    my @quota_types      = $ak->quota_groups();
    my $quota_types_aref = $ak->quota_groups();

get all pre-defined quota groups, i.e. pre-defined splitting into
(weighted) quotas.

Depending on calling context, you will either get a list of quotas back,
or a reference to an array containing the quotas.

There are two types of quota groups: _plain_ and _finance_ (see
["Quotas"](#quotas) for details).

Each quota group returned is a hash reference with at least the
following keys:

- `id`

    identifier of the quota group, useful for retrieving it later. For
    _plain_ quota groups, it is the same as the `name` below; otherwise,
    it represents the group of sub-quotas associated to the specific
    `name`;

- `name`

    name of the quota group, used for retrieving it. For _plain_ quota
    groups, this is the same as `id`;

- `type`

    this is a string that can be either `plain` or `finance`.

For _finance_ quota groups, the following additional keys are
available:

- `maxs`

    the maximum value for `sequence_number`;

- `mins`

    the minimum value for `sequence_number`;

- `sequence_number`

    the next quota sub-group identifier.

## **transfer\_and\_contribution\_split**

    my @transfers = $ak->transfer_and_contribution_split(
       $transfer, $split);
    my $transfers = $ak->transfer_and_contribution_split(
       $transfer, $split);

perform a transfer and its split into contributions in one single
transaction. `$transfer` is a hash reference compatible with
["transfer\_record"](#transfer_record); `$split` is a split definition compatible with
["contribution\_split"](#contribution_split) (you can of course omit the transfer in this
case, as it will be overridden by the one created from `$transfer`).

Returns the list of transfers created, or a reference to an array with
the list in scalar context.

## **transfer\_and\_distribution\_split**

    my @transfers = $ak->transfer_and_distribution_split(
       $transfer, $split);
    my $transfers = $ak->transfer_and_distribution_split(
       $transfer, $split);

perform a transfer and its split into distributions in one single
transaction. `$transfer` is a hash reference compatible with
["transfer\_record"](#transfer_record); `$split` is a split definition compatible with
["distribution\_split"](#distribution_split) (you can of course omit the transfer in this
case, as it will be overridden by the one created from `$transfer`).

Returns the list of transfers created, or a reference to an array with
the list in scalar context.

## **transfer\_delete**

    $ak->transfer_delete($transfer);

wrapper around ["mark\_delete" in Accounting::Kitty::Result::Transfer](https://metacpan.org/pod/Accounting::Kitty::Result::Transfer#mark_delete), where
`$trasfer` is passed through ["fetch"](#fetch) to get to a real transfer
object. Does not return anything.

## **transfer\_record**

    my $transfer = $ak->transfer_record(\%def);

record a new transfer and get it back, _DWIM_my.

The input hash reference `\%def` has the following keys:

- `amount`

    the amount of the transaction;

- `date`

    the transaction date (and time), parsed via
    ["parse\_datetime" in DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime::Format::ISO8601#parse_datetime). Defaults to
    ["now" in DateTime](https://metacpan.org/pod/DateTime#now);

- `description`

    a string with the description of the transaction, optional (defaults to
    the empty string);

- `dst`

    the destination account, pass a `$query` compatible with ["fetch"](#fetch);

- `parent`

    the parent of the transaction, in case this is a split of an existing
    transaction. It can be either the parent's identifier, or another
    transaction object;

- `src`

    the source account, pass a `$query` compatible with ["fetch"](#fetch);

- `title`

    a string with the title of the transaction, optional (defaults to the
    empty string).

If the `amount` is negative, `dst` and `src` are swapped and the
transfer is recorded with a positive amount (i.e. as the opposite of the
provided `amount`).

# BUGS AND LIMITATIONS

Report bugs either through RT or GitHub (patches welcome).

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
