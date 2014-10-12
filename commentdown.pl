#!/bin/perl/bin/

BEGIN {
        use File::Basename;
        unshift(@INC, dirname($0)."/lib");
}

use strict;
use R::Comment2Man;

my $package = shift;

chdir $package;
R::Comment2Man->draft('R');
