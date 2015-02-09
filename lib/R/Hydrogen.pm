package R::Hydrogen;

use strict;
use English;
use File::Temp qw(tempfile);
use Data::Dumper;
use R::Hydrogen::Single;

our $VERSION = 0.4;

our $DIR = ".";

# entrance
sub hydrogenize {
    my $class = shift;
    my $dir = shift;
    my %settings = (overwrite => 0,
	                @_);
    
    my ($R_MERGE_FH, $r_merge_filename) = tempfile();
    
    # find all the R script
    my @r_files;
    if( -f $dir) {   # if only one R script
        @r_files = ($dir);
    } elsif(-d $dir) {    # if it is a dir
        @r_files = glob("$dir/*.R");
    } else {
        die "cannot find $dir.\n";
    }

    $DIR = "$dir/../";
    
    # merge all the R script into one file
    foreach my $r_file (@r_files) {
        print "- merge $r_file\n";
        
        open my $R_FH, "<", $r_file or die "cannot create $r_file.";
        print $R_MERGE_FH join "", <$R_FH>;
        print $R_MERGE_FH "\n\n";
        close $R_FH; 
    }
    
    close $R_MERGE_FH;
    
    print "R scripts are merged into $r_merge_filename\n";
    print "Now convert the comments\n";
	
	if(-e "$DIR/man" and !(-d "$DIR/man")) {
		print("$DIR/man already exists, but it shold be a folder. Exit.\n");
		exit;
	}

	# if there is no 'man' folder
	if(! -e "$DIR/man") {
		mkdir("$DIR/man");
	}
	
	# parse the comments and write into files
	parse($r_merge_filename, $settings{overwrite});
    
    print "Remove temp files ($r_merge_filename)\n";
    unlink($r_merge_filename);
    
    print "Done, you documentations are in $DIR/man folder.\n\n";
}

# parse comments and write into files
sub parse {
	open my $R_FH, $_[0] or die $@;
	my $is_overwrite = $_[1];
	my @lines = <$R_FH>;
	
	# each `item` in @item contains information corresponds to each section
	# one the first level of `item` hash, there are two keys
	# -section is a reference of hash in which each key corresponds to each section
	# -meta is a reference of hash which contains meta information such as the type of the page
	my @items;
	my $i_item = 0;
    for(my $i = 0; $i < scalar(@lines); $i ++) {

    	my $line = $lines[$i];
		my $item;
		
		if($line =~/^#\s+[=@#*\-+$%&]{2}\s*title\s*/) {
			$item = R::Hydrogen::Single->new()->read(\@lines, $i);
			push(@items, $item);
		}
	}
	
	@items = sort { $a->meta("page_name") cmp $b->meta("page_name") } @items;
	
	# export* can be generated from source code
	# but import* function should be re-stored from NAMESPACE
	my @import;
	if(-e "$DIR/NAMESPACE") {
		print "read already-existed import* directives.\n";
		open NAMESPACE, "$DIR/NAMESPACE";
		while(my $line = <NAMESPACE>) {
			if($line =~/^import/i) {
				push(@import, $line);
			}
		}
		close(NAMESPACE);
	}
	
	my @parsed_items;
	for(my $i = 0; $i < scalar(@items); $i ++) {

		my $s;
		my $man_file = "$DIR/".$items[$i]->meta("page_name").".rd";
		if($is_overwrite) {
			$s = $items[$i]->parse()->string();
		} else {
			my $it1 = $items[$i]->parse();
			my $it2 = read_man_file($man_file);

			$s = R::Hydrogen::Single::combine($it1, $it2);
		}

		open MAN, ">$man_file";
		print MAN $s->string();
		close MAN;

		print "$man_file... done.\n\n";
	}


	open NAMESPACE, ">$DIR/NAMESPACE";
	for(my $i = 0; $i < scalar(@items); $i ++) {
		my $str = $items[$i]->export_str();
		if($str ne "") {
			print NAMESPACE "$str\n";
		}
	}
	
	print NAMESPACE "\n";
	print NAMESPACE join "", @import;
	print NAMESPACE "\n";
	
	close NAMESPACE;
	
}

1;
