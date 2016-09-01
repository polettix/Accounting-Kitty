package Accounting::Kitty::TransferProxy;

use utf8;
use strict;
use warnings;
use Carp;
{ our $VERSION = '0.001'; }

sub new {
   my $package = shift;
   return bless +{(@_ && ref($_[0])) ? %{$_[0]} : @_}, $package;
}

sub src {
   my $self = shift;
   return $self->{invert}
     ? $self->{transfer}->dst(@_)
     : $self->{transfer}->src(@_);
} ## end sub src

sub dst {
   my $self = shift;
   return $self->{invert}
     ? $self->{transfer}->src(@_)
     : $self->{transfer}->dst(@_);
} ## end sub dst

sub transfer {
   my $self = shift;
   return $self->{transfer};
}

sub amount {
   my $self   = shift;
   my $invert = $self->{invert};
   if (@_) {
      my $amount = shift;
      $self->{transfer}->amount($invert ? -$amount : $amount);
   }
   my $amount = $self->{transfer}->amount();
   return $invert ? -$amount : $amount;
}

# delegate all other calls to proxied transfer
sub AUTOLOAD {
   my $self = shift;
   (my $name = our $AUTOLOAD) =~ s{.*::}{}mxs;
   my $proxied = $self->{transfer};
   my $method = $proxied->can($name)
     or croak "invalid method: '$name'";
   return $proxied->$method(@_);
} ## end sub AUTOLOAD

1;
__END__

# Keep the following methods around, just in case temporarily

sub amount_euros {
   return sprintf '%.02lf', $_[0]->amount() / 100;
}

sub negative_amount_euros {
   return sprintf '%.02lf', $_[0]->amount() / -100;
}

sub DESTROY {
   my $self = shift;
   %$self = ();
}

sub supports_attribution {
   my $self = shift;
   $self->{_supports_attribution} = shift if @_;
   return $self->{_supports_attribution}
     if exists $self->{_supports_attribution};
   return 1;
   my $proxied = $self->{_transfer};
   return $proxied->attributable() || $proxied->attributed();
} ## end sub supports_attribution
