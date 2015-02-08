# align two vectors
# you can think of it as aligning two DNA sequences
# this is a global alignment
# using dynamic programming
package R::Hydrogen::Align;
use strict;
use Data::Dumper;

sub align {
	my $array1 = shift;
	my $array2 = shift;

	my $tr = align_score_matrix($array1, $array2);
	my ($align1, $align2) = align_traceback($array1, $array2, $tr);

	return ($align1, $align2);
}

# get the score matrix and return the trace-back matrix
sub align_score_matrix {
	my $array1 = shift;
	my $array2 = shift;
	
	my $m = [[]];
	my $traceback = [[]];
	# you can think there is additional letter which is a blank
	# in front of both two vectors and is the start point
	for(my $i = 0; $i <= scalar(@$array1); $i ++) {
		$m->[$i]->[0] = 0;
		$traceback->[$i]->[0] = [ $i - 1, 0];
	}
	for(my $i = 0; $i <= scalar(@$array2); $i ++) {
		$m->[0]->[$i] = 0;
		$traceback->[0]->[$i] = [0, $i - 1];
	}
	
	my $direction;
	
	for(my $i = 1; $i <= scalar(@$array1); $i ++) {
		for(my $j = 1; $j <= scalar(@$array2); $j ++) {
			# calculate the score according to the score rule
			# and record which position the value comes from
			($m->[$i]->[$j], $direction) = align_score($m->[$i]->[$j-1],
			                       $m->[$i-1]->[$j-1],
								   $m->[$i-1]->[$j],
								   $array1->[$i-1] eq $array2->[$j-1]);
			# record the source
			if($direction eq "left") {
				$traceback->[$i]->[$j] = [$i, $j - 1];
			} elsif($direction eq "topleft") {
				$traceback->[$i]->[$j] = [$i - 1, $j - 1];
			} elsif($direction eq "top") {
				$traceback->[$i]->[$j] = [$i - 1, $j];
			}
		}
	}
	
	return $traceback;
}

# find the maximum value which is coming from
# left, topleft and top positions
sub align_score {
	my $left = shift;
	my $topleft = shift;
	my $top = shift;
	my $is_matched = shift;
	
	my %s = ("matched" => 10,
	         "wrong_matched" => -10,
			 "blank" => 0);
	
	$topleft = $is_matched ? $topleft + $s{matched} : $topleft + $s{wrong_matched};
	$left += $s{blank};
	$top += $s{blank};
	
	if($left >= $topleft and $left >= $top) {
		return($left, "left");
	} elsif($topleft >= $left and $topleft >= $top) {
		return($topleft, "topleft");
	} else {
		return($top, "top");
	}
}

# trace back from bottom right in the matrix
# and finally get the alignment
sub align_traceback {
	my $array1 = shift;
	my $array2 = shift;
	my $traceback = shift;
	
	my $align1 = [];
	my $align2 = [];
	
	my $a = [];
	my $i = scalar(@$array1);
	my $j = scalar(@$array2);

	# this is the trace-back path
	unshift(@$a, [$i, $j]);
	while($i >= 0 and $j >= 0) {
		($i, $j) = @{$traceback->[$i]->[$j]};
		if(!($i == -1 or $j == -1)) {
			unshift(@$a, [$i, $j]);
		}
	}
	
	shift(@$a);

	# then we can know the alignment
	for(my $i = 0; $i < scalar(@$a); $i ++) {
		if($a->[$i]->[0] == 0) {
			push(@$align1, "");
		} elsif($i > 0 and $a->[$i]->[0] == $a->[$i - 1]->[0]) {
			push(@$align1, "");
		} else {
			push(@$align1, $array1->[$a->[$i]->[0] - 1]);
		}
		
		if($a->[$i]->[1] == 0) {
			push(@$align2, "");
		} elsif($i > 0 and $a->[$i]->[1] == $a->[$i - 1]->[1]) {
			push(@$align2, "");
		} else {
			push(@$align2, $array2->[$a->[$i]->[1] - 1]);
		}
	}
	
	return($align1, $align2);
}


1;
