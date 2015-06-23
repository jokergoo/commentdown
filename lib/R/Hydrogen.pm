package R::Hydrogen;

use strict;
use English;
use File::Temp qw(tempfile);
use Data::Dumper;
use R::Hydrogen::Single;

our $VERSION = 0.4;

our $DIR = ".";

# the main function
# input is the path of the R package, like /path/to/circlize
#
# settings:
# -overwrite: directly overwrite the rd file if it exists
#
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
        @r_files = glob("$dir/R/*.R");
    } else {
        die "cannot find $dir.\n";
    }

    $DIR = "$dir";
    
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

# second step:
#   aftering merging all R scripts into one script
#   1. find comment for every function
#   2. find section in every comment
#   3. parse the comment as a tree
sub parse {
	open my $R_FH, $_[0] or die $@;
	my $is_overwrite = $_[1];
	my @lines = <$R_FH>;
	
	# each `item` in @item contains information corresponds to each section
	# one the first level of `item` hash, there are two keys
	# -section is a reference of hash in which each key corresponds to each section
	# -meta is a reference of hash which contains meta information such as the type of the page
	my @items;  # items are functions/classes/...
	my $i_item = 0;
    for(my $i = 0; $i < scalar(@lines); $i ++) {

    	my $line = $lines[$i];
		my $item;
		
		if($line =~/^#\s+[=@#*\-+$%&]{2}\s*title\s*/) {
			$item = R::Hydrogen::Single->new()->read(\@lines, $i)->parse();
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
	
	print "\n";
	
	my $S4method = {};
	for(my $i = 0; $i < scalar(@items); $i ++) {
		if($items[$i]->meta("page_type") eq "S4method") {
			$S4method->{$items[$i]->meta("page_function")}->{$items[$i]->meta("class")} = $i;
		}
	}

	# generate s4 method dispatch pages
	foreach my $method (keys %$S4method) {

		my $class = [keys %{$S4method->{$method}}];

		if(scalar(@$class) == 1) {
			# insert an alias which is function name to the page
			my $i = $S4method->{$method}->{$class->[0]};
			
			my $alias = R::Hydrogen::Section->new("alias");
			$alias->{tex} = $method;
			push(@{$items[$i]->{section}}, $alias);
			next;
		}

		my $s = R::Hydrogen::Single::S4method_dispatch($method, $class);
		my $man_file = "$DIR/man/".filter_str($s->meta("page_name")).".rd";

		print "generating $man_file\n";
		if(!$is_overwrite) {
			my $it2 = R::Hydrogen::Single::read_man_file($man_file);

			if(defined($it2)) {
				print "merging with existed man file\n";
				$s = R::Hydrogen::Single::combine($s, $it2);
			} 
		}

		open MAN, ">$man_file";
		print MAN $s->string();
		close MAN;

		print "$man_file... done.\n\n";
	}

	for(my $i = 0; $i < scalar(@items); $i ++) {

		my $s;
		my $man_file = "$DIR/man/".filter_str($items[$i]->meta("page_name")).".rd";

		print "generating $man_file\n";
		if($is_overwrite) {
			$s = $items[$i];
		} else {
			my $it1 = $items[$i];
			my $it2 = R::Hydrogen::Single::read_man_file($man_file);
			
			if(defined($it2)) {
				print "merging with existed man file\n";
				$s = R::Hydrogen::Single::combine($it1, $it2);
			} else {
				$s = $it1;
			}
		}

		open MAN, ">$man_file";
		print MAN $s->string();
		close MAN;

		print "$man_file... done.\n\n";

		# if($items[$i]->meta("page_name") eq "Heatmap-class") { exit; }
	}


	my $export = {};
	for(my $i = 0; $i < scalar(@items); $i ++) {
		my $str = $items[$i]->export_str();
		if($str ne "") {
			$export->{$str} = 1;
		}
	}
	open NAMESPACE, ">$DIR/NAMESPACE";
	foreach my $e (keys %$export) {
		print NAMESPACE "$e\n";
	}
	
	print NAMESPACE "\n";
	print NAMESPACE join "", @import;
	print NAMESPACE "\n";
	
	close NAMESPACE;

	## S4 generic function
	if(scalar(%$S4method)) {
		open GENERIC, ">$DIR/R/00_S4_generic_methods.R";
		foreach my $method (keys %$S4method) {
			next if ($method eq "initialize" || $method eq "show");
			print GENERIC generate_generic_method($method);
		}
		close GENERIC;
	}
}

sub filter_str {
	my $str = shift;

	$str =~s/\+/add/g;
	#$str =~s/["']//g;

	return $str;
}


sub generate_generic_method {
	my $method = shift;

	my $code = "
setGeneric('$method', function(object, ...) standardGeneric('$method'))
";
	return $code;
}

1;
