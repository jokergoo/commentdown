# this model defines a series of functions which read paragraph/list/code
# convert to tex

package R::Hydrogen::Format;
use strict;

require Exporter;
our @ISA = ("Exporter");

our @EXPORT = qw(
	read_item
	read_named_item
	read_code_block
	read_paragraph
	is_code_block
	inline_format
	trans_code
	trans_url
	trans_font
	);

#############################################
##  read from original comment
#############################################

# list with no name
sub read_item {
	my $lines_ref = shift;
	my $index = shift;
	
	my $item;
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		my $line = $lines_ref->[$i];
		chomp $line;
		if($lines_ref->[$i] =~/^-\s/) {
			$line =~s/^-\s+//;
			push(@$item, $line);
		} elsif($i == $#$lines_ref or $line eq "") {
			return ($item, $i);
		} else {
			$line =~s/^\s+//;
			$item->[$#$item] .= " $line";
		}
	}
}

# list with names
sub read_named_item {
	my $lines_ref = shift;
	my $index = shift;
	
	my $item = {name => [], value => []};
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		my $line = $lines_ref->[$i];
		chomp $line;
		if($lines_ref->[$i] =~/^-(\S+)\s/) {
			push(@{$item->{name}}, $1);
			$line =~s/^-\S+\s+//;
			push(@{$item->{value}}, $line);
		} elsif($i == $#$lines_ref or $line eq "") {
			return ($item, $i);
		} else {
			$line =~s/^\s+//;
			$item->{value}->[$#{$item->{value}}] .= " $line";
		}
	}
}

sub read_code_block {
	my $lines_ref = shift;
	my $index = shift;
	
	my $code_block;
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		
		if($lines_ref->[$i] =~/^\s+\S/) {
			for(; $i < scalar(@$lines_ref); $i ++) {
				my $line = $lines_ref->[$i];
				
				
				$line =~s/^\s{2}//;
				if($line eq "") {
					$line = "\n";
				}
				if($line =~/\\n$/) {
					$code_block .= $line;
				} else {
					$code_block .= "$line\n";
				}
				if($i == $#$lines_ref or ($lines_ref->[$i + 1] =~/^\s*$/ and $lines_ref->[$i+2] !~/^\s+\S/)) {
					return ($code_block, $i);
				}
			}
		}
	}
}

sub read_paragraph {
	my $lines_ref = shift;
	my $index = shift;
	
	my $paragraph;
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		my $line = $lines_ref->[$i];
		chomp $line;
		$paragraph .= "$line ";
		if($i == $#$lines_ref or $lines_ref->[$i] =~/^\s*$/) {
			return ($paragraph, $i);
		}
		
	}
}


# read several lines and check whether this is a code chunk
sub is_code_block {
	my $lines_ref = shift;
	my $index = shift;
	
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
	
		if($lines_ref->[$i] =~/^\s+\S/) {
			
			if($i == $#$lines_ref or $lines_ref->[$i + 1] =~/^\s*$/) {
				return 1;
			}
		} else {
			return 0;
		}
	}
	return 0;
}



#####################################################
## convert to tex code
#####################################################


# something like url, code link, font ...
sub inline_format {
	my $str = shift;
	$str = trans_code($str);
	$str = trans_url($str);
	return $str;
}

# ``arg`` to \code{arg}
# `function` to \code{\link{function}}
# `package::function` to \code{\link[package]{function}}
sub trans_code {
    my $text = shift;
    
    $text =~s/``(.*?)``/\\code{$1}/g;
    
    $text =~s/`(.*?)`/
        my @a = split "::", $1;
        if(scalar(@a) == 2) {
            "\\code{\\link[$a[0]]{$a[1]}}";
        }
        else {
            "\\code{\\link{$a[0]}}";
        }
        /exg;
    return $text;
}

# http://xxx to \url{http:xxx}
sub trans_url {
    my $text = shift;

    $text =~s/(http|ftp|https)(:\/\/\S+)([\s\)\]\}\.,;:\]\)\}]*)/\\url{$1$2}$3/g;

    return $text;
}

sub trans_font {
	my $text = shift;
	$text =~s/\*\*(.*?)\*\*/\\textbf{$1}/g;
	$text =~s/__(.*?)__/\\textbf{$1}/g;
	$text =~s/(?!\*)\*(.*?)\*(?<!\*)/\\emph{$1}/g;
	$text =~s/(?!_)_(.*?)_(?<!_)/\\emph{$1}/g;

	return $text;
}


1;
