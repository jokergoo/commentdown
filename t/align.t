
use R::Hydrogen::Align;


my $array1;
my $array2;
my $align1;
my $align2;

$array1 = ["a", "b", "d", "f"];
$array2 = ["b", "c", "e", "f"];

($align1, $align2) = R::Hydrogen::Align::align($array1, $array2);

print_alignment($align1, $align2);


$array1 = ["0", "a", "b", "d", "f", "g", "h", "i"];
$array2 = ["b", "c", "e", "f"];

($align1, $align2) = R::Hydrogen::Align::align($array1, $array2);

print_alignment($align1, $align2);

$array1 = ["b", "d", "f"];
$array2 = ["a", "b", "c", "e", "f", "g"];

($align1, $align2) = R::Hydrogen::Align::align($array1, $array2);

print_alignment($align1, $align2);

$array1 = ["a", "b", "c"];
$array2 = ["d", "e", "f"];

($align1, $align2) = R::Hydrogen::Align::align($array1, $array2);

print_alignment($align1, $align2);

$array2 = ["a", "b", "c"];
$array1 = ["d", "e", "f"];

($align1, $align2) = R::Hydrogen::Align::align($array1, $array2);

print_alignment($align1, $align2);

sub print_alignment {
	my $a1 = shift;
	my $a2 = shift;

	print "Alignment:\n";
	for(my $i = 0; $i < scalar(@$a1); $i ++) {
		print "$a1->[$i]\t$a2->[$i]\n";
	}
	print "\n";

}