package Accounting::Kitty;

use utf8;
use strict;
use warnings;
use Carp;
{ our $VERSION = '0.001'; }

use Scalar::Util qw< blessed >;
use DateTime;
use DateTime::Format::ISO8601 ();
use 5.010;
use List::Util qw< shuffle >;
use Storable qw< dclone >;

use Accounting::Kitty::Util qw< round >;

use base 'DBIx::Class::Schema';
__PACKAGE__->load_namespaces;


sub accounts {
   my $self = shift;
   my @retval;
   if (@_) {
      @retval = $self->resultset('Account')->search(@_);
   }
   else {
      @retval = $self->resultset('Account')->all();
   }
   return @retval if wantarray();
   return \@retval;
} ## end sub accounts

sub _divide_in_quotas {
   my ($self, $quota_type, $amount, $cb, $exact) = @_;

   if (ref($quota_type)) {
      return unless @$quota_types;
      return $self->_divide_in_quotas_exact($quota_type, $amount, $cb)
        if defined($quota_type->[0]{amount});
      return $self->_divide_in_quotas_weighted($quota_type, $amount, $cb);
   }

   my ($type, $identifier) = split /:/, $quota_type, 2;
   ($type, $identifier) = (plain => $type) unless defined $identifier;

   return $self->_divide_in_quotas_finance($identifier, $amount, $cb)
     if $type eq 'finance';
   return $self->_divide_in_quotas_plain($identifier, $amount, $cb);
} ## end sub divide_in_quotas

sub _divide_in_quotas_finance {
   my ($self, $quota_type, $amount, $cb) = @_;
   my ($group_id, $sequence_number) = split /:/, $quota_type;

   my $rs = $self->resultset('QuotaFinance');

   # selection of totals
   my @total_quotes = $rs->search(
      {
         group_id        => $group_id,
         sequence_number => {'>=', $sequence_number},
      },
      {
         select   => [qw< account_id >, {sum => 'weight'}],
         as       => [qw< account_id weight >],
         group_by => 'account_id',
         order_by => 'account_id',
      }
   );

   my @next_quotes = $rs->search(
      {
         group_id        => $group_id,
         sequence_number => $sequence_number,
      },
      {
         order_by => 'account_id',
      },
   );

   croak 'different sizes?!?'
     unless scalar(@next_quotes) == scalar(@total_quotes);

   my %quotas;
   for my $i (0 .. $#total_quotes) {
      my $total = $total_quotes[$i];
      my $next  = $next_quotes[$i];

      my $id = $next->account()->id();
      croak 'different accounts?!?'
        if $id ne $total->account()->id();

      my $a_amount = $next->weight();
      $quotas{$id} = {
         account => $id,
         amount  => $a_amount,
         weight  => $total->weight(),
      };
      $amount -= $a_amount;
   } ## end for my $i (0 .. $#total_quotes)

   # the remaining amount has to be divided according to the residuals
   $self->_divide_in_quotas_weighted(
      [values %quotas],
      $amount,
      sub {
         $quotas{$_->{account}}{amount} += $_->{amount} for @_;
      }
   ) if $amount;

   $self->txn_do(
      sub {
         $cb->(values %quotas) if $cb;    # assign quotas
         for my $item (@next_quotes) {
            $item->is_active(0);
            $item->update();
         }
      }
   );
   return values %quotas;
} ## end sub divide_in_quotas_finance

sub _divide_in_quotas_plain {
   my ($self, $quota_type, $amount, $cb, $exact) = @_;

   # The $reference will be the parent transaction.
   my $rs = $self->resultset('Quota');
   my @quotas = map { {value => $_->value(), account => $_->account(),} }
     $rs->search({name => $quota_type}, {order_by => 'id'});

   return $self->_divide_in_quotas_weighted(\@quotas, $amount, $cb);
} ## end sub divide_in_quotas_plain

sub _divide_in_quotas_exact {
   my ($self, $quotas, $amount, $cb) = @_;

   # do a few checks
   my $total = 0;
   for my $q (@$quotas) {
      croak 'quotas need to contain "amount" for exact splitting'
        unless defined $q->{amount};
      $total += $q->{amount};
   }
   croak 'cannot divide into exact quotas, total does not match amount'
     if $total != $amount;

   $cb->(@$quotas) if $cb;
   return @$quotas;
}

sub _divide_in_quotas_weighted {
   my ($self, $quota_type, $amount, $cb) = @_;

   # shallow copy suffices, we only operate on the first level. We
   # do some shuffling so that the accumulated rounding is spread
   # possibly in an even way over multiple splits
   my @quotas = shuffle map { { %$_ } } @$quota_type;    # be fair?

   my $total = 0;
   for my $q (@quotas) {
      croak 'quotas need to contain "weight" for weighted splitting'
        unless defined $q->{weight};
      $total += $q->{weight};
   }

   my $accumulated = 0;
   for my $q (@quotas) {
      $q->{amount} = round($amount * $q->{weight} / $total);
      $accumulated += $q->{amount};
   }
   $quotas[-1]{amount} += $amount - $accumulated;   # adjust roundings

   $cb->(@quotas) if $cb;
   return @quotas;
}

sub fetch {
   my $self = shift;
   my @retval;
   while (@_) {
      my ($what, $query) = splice @_, 0, 2;
      if (defined $query) {
         $query = {id => $query} unless ref $query;
         if (blessed $query) {
            push @retval, $query;
         }
         else {
            push @retval, $self->resultset($what)->search($query);
         }
      }
      else {
         push @retval, undef;
      }
      last unless wantarray();
   } ## end while (@_)

   return $retval[0] unless wantarray();
   return @retval;
} ## end sub fetch

sub quota_types {
   my $self = shift;
   my @qts = ($self->quota_types_plain(), $self->quota_types_finance());
   return @qts if wantarray();
   return \@qts;
}

sub _quota_types_finance {
   my $self = shift;
   my $rs   = $self->resultset('QuotaFinance');

   my @limits = $rs->search(
      {is_visible => 1},
      {
         group_by => 'group_id',
         order_by => 'group_id',
         select   => [
            qw< name group_id >,
            {min => 'sequence_number'},
            {max => 'sequence_number'}
         ],
         as => [qw< name group_id mins maxs >],
      }
   );

   my %next_for =
     map { $_->group_id() => $_->get_column('next') } $rs->search(
      {is_visible => 1, is_active => 1},
      {
         group_by => 'group_id',
         order_by => 'group_id',
         select   => [qw< group_id >, {min => 'sequence_number'},],
         as       => [qw< group_id next >],
      }
     );

   return map {
      {
         name            => $_->name(),
         id              => $_->group_id(),
         sequence_number => $next_for{$_->group_id()},
         mins            => $_->get_column('mins'),
         maxs            => $_->get_column('maxs'),
         type            => 'finance',
      }
   } @limits;
} ## end sub quota_types_finance

sub _quota_types_plain {
   my $self = shift;
   my @plains =
     map { {name => $_, id => $_, type => 'plain',} }
     $self->resultset('Quota')->search({}, {distinct => 1})
     ->get_column('name')->all();
   return @plains if wantarray();
   return \@plains;
} ## end sub quota_types_plain

sub transfer_contribution_split {
   my ($self, $params) = @_;
   return $self->_transfer_split(
      {
         %$params,
         src => undef,
         dst => $params->{transfer}->src(),
      }
   );
} ## end sub record_contribution

sub transfer_distribution_split {
   my ($self, $params) = @_;
   return $self->_transfer_split(
      {
         %$params,
         src => $params->{transfer}->dst(),
         dst => undef,
      }
   );
} ## end sub record_distribution

sub transfer_delete {
   my ($self, $transfer) = @_;
   $self->fetch(Transfer => $transfer)->mark_deleted();
} ## end sub delete_transfer

sub transfer_record {
   my ($self, $t)   = @_;
   my ($src,  $dst) = $self->fetch(
      Account => $t->{src},
      Account => $t->{dst}
   );
   my $amount = $t->{amount};
   ($amount, $src, $dst) = (-$amount, $dst, $src)
      if $amount < 0;
   my $date = $t->{date} // DateTime->now();
   $date = DateTime::Format::ISO8601->parse_datetime($date)
     unless blessed($date) && $date->isa('DateTime');
   my $transfer = $self->resultset('Transfer')->create(
      {
         src         => $src,
         dst         => $dst,
         tdate       => $date,
         title       => $t->{title} // '',
         description => $t->{description} // '',
         amount      => $amount,
         parent      => $t->{parent},
      }
   );

   if (!exists $t->{parent}) {
      $transfer->parent($transfer->id());
      $transfer->update();
   }

   $src->subtract_amount($amount);
   $dst->add_amount($amount);

   return $transfer;
} ## end sub transfer_record

sub _transfer_split {
   my $self   = shift;
   my $params = shift;

   # The $reference will be the parent transfer
   my ($src, $dst) = $self->fetch(
      Account => $params->{src},
      Account => $params->{dst},
   );
   croak "provide one of dst or src for splitting a transfer"
     unless defined($src // $dst);
   croak "provide only one of dst or src for splitting a transfer"
     if defined($src) && defined($dst);

   my $reference = $self->fetch(Transfer => $params->{transfer})
     or croak "cannot determine transfer";
   my $amount = $reference->amount();

   my $quota_type = $params->{quota_type};
   croak "provide hints for dividing in quotas"
     unless defined($quota_type);

   $self->_divide_in_quotas(
      $quota_type,
      $amount,
      sub {
         for my $q (@_) {
            $self->transfer_record(
               {
                  $reference->as_hash(),    # defaults from parent...
                  %$params,                 # what was passed in...
                  src => $src // $q->{account},
                  dst => $dst // $q->{account},
                  amount => $q->{amount},
                  parent => $reference,
               }
            );
         } ## end for my $q (@_)
      }
   );

   return;
} ## end sub record_attribution

1;
__END__

sub proper_quota_types {
   my $self = shift;
   return [$self->resultset('Quota')
        ->search({}, {group_by => 'name', having => \'count(*) > 1'})
        ->get_column('name')->all()
   ];
} ## end sub proper_quota_types
