
use R::Hydrogen::Section;
use Data::Dumper;
use strict;

my $line_array = ["this is a paragrame",
                  "continue last line",
				  "",
				  "- list1",
				  "- lits2",
				  "",
				  "-n1 name1",
				  "-n2 name2",
				  "",
				  "    a = 1",
				  "    b = 2",
				  ""];

my $section = R::Hydrogen::Section->new("details");
for(my $i = 0; $i < scalar(@$line_array); $i ++) {
	$section->add_line($line_array->[$i]);
}

$section->parse();

print Dumper $section;