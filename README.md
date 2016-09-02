# NAME

Accounting::Kitty - Simple accounting system for a shared fund

# VERSION

This document describes Accounting::Kitty version {{\[ version \]}}.

# SYNOPSIS

    use Accounting::Kitty;

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

To generate transfers for a split, use ["transfer\_contribution\_split"](#transfer_contribution_split)
and ["transfer\_distribution\_split"](#transfer_distribution_split). They have the same interface,
accepting a hash reference `\%def` with the following keys:

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

In ["transfer\_contribution\_split"](#transfer_contribution_split) and ["transfer\_distribution\_split"](#transfer_distribution_split),
there are a few ways in which you can divide a transfer into _quotas_
(via parameter ["quota\_type"](#quota_type)), depending on the flexibility level that
you need.

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

# FUNCTIONS

## **whatever**

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

## **transfer\_contribution\_split**

    $ak->transfer_contribution_split(\%def);

See ["Transfer Splitting"](#transfer-splitting).

## **transfer\_distribution\_split**

    $ak->transfer_distribution_split(\%def);

See ["Transfer Splitting"](#transfer-splitting).

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

# SEE ALSO

Foo::Bar.

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
