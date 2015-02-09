
use R::Hydrogen::Single;
use strict;
use Data::Dumper;

my $text = "
# == title
# sth
#
# == param
# -n1 param1
# -n2 param2
#
# == details
# sssss
#
setMethod(f = 'foo',
	signature = 'bar',
    definition = function(n1, n2) {

}
";

my $line_ref = [split "\n", $text];
my $single = R::Hydrogen::Single->new();
$single->read($line_ref, 1);
$single->parse();
#print $single->sort()->string();
#print Dumper $single;

my $text = '
\a{
1
}
\section{b}{
s
}
';

my $m;
	$m = qr/
			\{
			  (?:
				[^{}]+
			   |
				 (?:(??{$m}))
			   )*
			 \}
			/x;

	my @a = $text =~ /\\(\w+(\{\w+\})?)\s*($m)/gs;
map {print "$_\t$a[$_]\n\n"} 0..$#a;
