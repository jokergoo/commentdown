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
			if($line !~/^(export|S3method)/i) {
				if($line !~/^\s*$/) {
					push(@import, $line);
				}
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
		my $man_file = "$DIR/man/".filter_str($s->meta("page_name")).".Rd";

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
		my $man_file;
		if($items[$i]->meta("page_name") eq "heatmap") {
			$man_file = "$DIR/man/stats_heatmap.Rd";
		} else {
			$man_file = "$DIR/man/".filter_str($items[$i]->meta("page_name")).".Rd";
		}

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
		if(!$s->has_section("examples")) {
			print MAN "\\examples{\n# There is no example\nNULL\n}\n";
		}
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
	foreach my $e (sort keys %$export) {
		print NAMESPACE "$e\n";
	}
	
	print NAMESPACE "\n";
	print NAMESPACE join "", sort @import;
	print NAMESPACE "\n";
	
	close NAMESPACE;

	## S4 generic function
	if(scalar(%$S4method)) {
		open GENERIC, ">$DIR/R/00_S4_generic_methods.R";
		foreach my $method (keys %$S4method) {
			if(!is_s4_generic($method)) {
				if($method ne "show") {
					print GENERIC generate_generic_method($method);
				}
			}
		}
		close GENERIC;
	}
}

sub filter_str {
	my $str = shift;

	$str =~s/\+/add/g;
	$str =~s/\[/Extract/g;
	$str =~s/\$<-/Assign/g;
	$str =~s/<-/Assign/g;
	$str =~s/\$/Subset/g;
	$str =~s/^\./Dot./g;
	$str =~s/^\%/pct_/g;
	$str =~s/\%$/_pct/g;

	return $str;
}


sub generate_generic_method {
	my $method = shift;

	my $code;
	if($method =~/<-$/) {
		$code = "setGeneric('$method', function(object, value, ...) standardGeneric('$method'))\n";
	} else {
		$code = "setGeneric('$method', function(object, ...) standardGeneric('$method'))\n";
	}
	return $code;
}

sub is_s4_generic {
	my $method = shift;

	my $s4_generic = {
		"annotation" => 1,
		"anyDuplicated" => 1,
		"append" => 1,
		"as.data.frame" => 1,
		"as.list" => 1,
		"boxplot" => 1,
		"cbind" => 1,
		"clusterApply" => 1,
		"clusterApplyLB" => 1,
		"clusterCall" => 1,
		"clusterEvalQ" => 1,
		"clusterExport" => 1,
		"clusterMap" => 1,
		"clusterSplit" => 1,
		"colnames" => 1,
		"combine" => 1,
		"conditions" => 1,
		"counts" => 1,
		"dbconn" => 1,
		"dbfile" => 1,
		"density" => 1,
		"design" => 1,
		"dispTable" => 1,
		"do.call" => 1,
		"duplicated" => 1,
		"end" => 1,
		"estimateDispersions" => 1,
		"estimateSizeFactors" => 1,
		"eval" => 1,
		"fileName" => 1,
		"Filter" => 1,
		"Find" => 1,
		"get" => 1,
		"grep" => 1,
		"grepl" => 1,
		"image" => 1,
		"intersect" => 1,
		"invertStrand" => 1,
		"IQR" => 1,
		"is.unsorted" => 1,
		"lapply" => 1,
		"lengths" => 1,
		"mad" => 1,
		"Map" => 1,
		"mapply" => 1,
		"match" => 1,
		"mget" => 1,
		"ncol" => 1,
		"NCOL" => 1,
		"normalize" => 1,
		"nrow" => 1,
		"NROW" => 1,
		"order" => 1,
		"organism" => 1,
		"parApply" => 1,
		"parCapply" => 1,
		"parLapply" => 1,
		"parLapplyLB" => 1,
		"parRapply" => 1,
		"parSapply" => 1,
		"parSapplyLB" => 1,
		"paste" => 1,
		"plotDispEsts" => 1,
		"plotMA" => 1,
		"plotPCA" => 1,
		"pmax" => 1,
		"pmax.int" => 1,
		"pmin" => 1,
		"pmin.int" => 1,
		"Position "=> 1,
		"rank" => 1,
		"rbind" => 1,
		"Reduce" => 1,
		"relist" => 1,
		"rep.int" => 1,
		"residuals" => 1,
		"rownames" => 1,
		"sapply" => 1,
		"score" => 1,
		"setdiff" => 1,
		"sizeFactors" => 1,
		"sort" => 1,
		"species" => 1,
		"start" => 1,
		"strand" => 1,
		"subset" => 1,
		"table" => 1,
		"tapply" => 1,
		"union" => 1,
		"unique" => 1,
		"unsplit" => 1,
		"updateObject" => 1,
		"weights" => 1,
		"which" => 1,
		"which.max" => 1,
		"which.min" => 1,
		"width" => 1,
		"xtabs" => 1,
		"show" => 1,
	};

	if($s4_generic->{$method}) {
		return 1;
	} else {
		return 0;
	}
};

1;
