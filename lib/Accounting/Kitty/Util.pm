package Accounting::Util::Kitty;

use utf8;
use strict;
use warnings;
use 5.010;
{ our $VERSION = '0.001'; }

use Exporter 'import';
our @EXPORT_OK = qw< int2dec round >;
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

sub int2dec {
   use integer;
   my ($amount, $digits) = @_;
   $digits //= 2;
   my $divisor = 1;
   $divisor *= 10 for 1 .. $digits;
   my $int = $amount / $divisor;
   my $dec = $amount % $divisor;
   $dec = -$dec if $dec < 0;
   return sprintf "%d.%0${digits}d", $int, $dec;
} ## end sub c2e

sub round {
   return -round(-$_[0]) if $_[0] < 0;
   return int($_[0] + 0.5);
}

1;
