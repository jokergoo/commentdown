# comments for a single R function
package R::Hydrogen::Single;
use English;
use Data::Dumper;
use R::Hydrogen::Section;
use R::Hydrogen::Align;
use Storable;
use strict;

# transform the wrong section names to right names
# this table can be extended
sub check_synonyms {
	my %s = ("desc"       => "description",
             "parameters" => "arguments",
             "param"      => "arguments",
             "args"       => "arguments",
             "arg"        => "arguments",
             "return"     => "value",
             "values"     => "value",
             "reference"  => "references",
             "ref"        => "references",
             "detail"     => "details",
             "authors"    => "author"
                );
	if($s{lc($_[0])}) {
		return $s{lc($_[0])};
	} else {
		return lc($_[0]);
	}
}

sub new {
	my $class = shift;

	my $self = {meta => {}, section => []};
	bless $self, $class;
	return($self);
}

# contructor subroutine
# a valid instance should contain
# $self->{meta}
# $self->{meta}->{page_name}
# $self->{meta}->{page_type}
# $self->{section} = []
# ......
sub read {
	my $single = shift;
	
	my $lines_ref = shift;  # array reference of the line array which corresponds to the big source code
	my $index = shift;      # which line in @$lines_ref

	my $is_function = 0;
	if($lines_ref->[$index] =~/^#\s+[=@#*\-+$%&]{2}\s*title\s*$/) { # normal function
		# a function, but still can be function/S3method/S4method/S4class, ...
		# it will be filled later
		$is_function = 1;
	} elsif($lines_ref->[$index] =~/^#\s+[=@#*\-+$%&]{2}\s*title\s*\(\s*data:\s*(\S+)\s*\)/) {  # data page
		$single->meta(page_name => $1);
		$single->meta(page_type => "data");
		$single->meta(usage => "data($1)");
	} elsif($lines_ref->[$index] =~/^#\s+[=@#*\-+$%&]{2}\s*title\s*\(\s*package:\s*(\S+)\s*\)/) {  # package page
		$single->meta(page_name => "$1-package");
		$single->meta(page_type => "package");
	}
	
	my $sections;  # an array of R::Hydrogen::Section instances
	my $current_section;
	my $current_section_name;
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		my $line = $lines_ref->[$i];
		
		if($line =~/^#/) {
			if($line =~/^#\s+[@#=*\-+$%&]{2}\s*(\w+)/) {
				$current_section_name = $1;
				$current_section_name = check_synonyms($current_section_name);
				$current_section = R::Hydrogen::Section->new($current_section_name);

				push(@$sections, $current_section);
			} else {
				$line =~s/^#\s?//s;  # leading space
				$line =~s/^\s+$//g;  # tracing space
				#$line .= "\n";
				$current_section->add_line($line);
			}
		} elsif($is_function) {
			my @res = get_nearest_function_info($lines_ref, $i);
			
			$single->meta(page_function => $res[0]);
			$single->meta(usage => $res[1]);
			$single->meta(page_type => $res[2]);
			$single->meta(class => $res[3]);

			if($res[2] eq "S4class") {
				$single->meta(page_name => "$res[0]-class");
			} elsif($res[2] eq "S4method") {
				$single->meta(page_name => "$res[0]-$res[3]-method");
			} else {
				$single->meta(page_name => $res[0]);
			}

			last;
		} else {
			last;
		}
	}

	$single->{section} = $sections;

	return $single;
}

sub meta {
	my $self = shift;

	if(scalar(@_) == 1) {
		$self->{meta}->{$_[0]};
	} elsif(scalar(@_) == 2) {
		$self->{meta}->{$_[0]} = $_[1];

		return($self);
	} else {
		die "only one or two arguments.";
	}
}

sub n_sections {
	my $self = shift;
	return(scalar(@{$self->{section}}));
}

# wrapper, convert the comment to a simple tree
# the tree looks like
#  $sth->{title} = ''
#  $sth->{arguments} = ''
sub parse {
	my $self = shift;
	
	for(my $i = 0; $i < $self->n_sections(); $i ++) {
		$self->{section}->[$i]->parse();
	}

	# besides the sections that user specified
	# there should be more sections such as alias, description, ...

	if(!$self->has_section("description")) {
		my $description = Storable::dclone($self->get_section("title"));
		$description->{name} = "description";
		push(@{$self->{section}}, $description);
	}

	# name
	my $name = R::Hydrogen::Section->new("name");
	$name->{tex} = $self->meta("page_name");
	push(@{$self->{section}}, $name);

	my $page_type = $self->meta("page_type");

	# alias
	if($page_type eq "S4class") {

		my $alias = R::Hydrogen::Section->new("alias");
		$alias->{tex} = $self->meta("page_name");
		push(@{$self->{section}}, $alias);

		$alias = R::Hydrogen::Section->new("alias");
		$alias->{tex} = $self->meta("page_function");
		push(@{$self->{section}}, $alias);

	} elsif($page_type eq "S4method") {
		my $alias = R::Hydrogen::Section->new("alias");
		# $alias->{tex} = $self->meta("page_function");
		# push(@{$self->{section}}, $alias);

		# $alias = R::Hydrogen::Section->new("alias");
		$alias->{tex} = $self->meta("page_function").",".$self->meta("class")."-method";
		push(@{$self->{section}}, $alias);

	} else {
		my $alias = R::Hydrogen::Section->new("alias");
		$alias->{tex} = $self->meta("page_name");
		push(@{$self->{section}}, $alias);
	}

	# docType
	my $docType = R::Hydrogen::Section->new("docType");
	if($page_type eq "S4class") {
		$docType->{tex} = "class";
		push(@{$self->{section}}, $docType);
	} elsif($page_type eq "package") {
		$docType->{tex} = "package";
		push(@{$self->{section}}, $docType);
	} elsif($page_type eq "data") {
		$docType->{tex} = "data";
		push(@{$self->{section}}, $docType);
	}
	

	# usage

	# my $class = $self->meta("class");
	# if($page_type eq "S4method" && $self->meta("page_function") eq "initialize") {
	# 	my $usage = $self->meta("usage");
	# 	$usage =~s/^\\S4method\{initialize\}\{$class\}\(\.Object[,\s]*/$class(/s;
	# 	$self->meta("usage" => $self->meta("usage")."\n\n#Constructor for $class class\n$usage\n");
	# }

	my $usage = R::Hydrogen::Section->new("usage");

	if(!($page_type eq "package" ||
	   $page_type eq "S4class")) {
		$usage->{tex} = $self->meta("usage");
		push(@{$self->{section}}, $usage);
	}

	# argument
	if($self->has_section("arguments")) {
		my $arguments = $self->get_section("arguments");
		$arguments->{tex} =~s/\\describe\{//s;
		$arguments->{tex} =~s/\}\s*$//s;
	}

	
	return $self->sort();
}

sub string {
	my $self = shift;

	my $output_str;
	for(my $i = 0; $i < $self->n_sections(); $i ++) {
		$output_str .= $self->{section}->[$i]->string();
	}
	return($output_str);
}

# whether the comment has this section
sub has_section {
	my $self = shift;
	my $section = shift;
	
	for(my $i = 0; $i < $self->n_sections(); $i ++) {
		if($self->{section}->[$i]->{name} =~/$section/i) {
			return !!1;
		}
	}
	return !!0;
}

sub get_section {
	my $self = shift;
	my $section = shift;
	
	for(my $i = 0; $i < $self->n_sections(); $i ++) {
		if($self->{section}->[$i]->{name} =~/$section/i) {
			return $self->{section}->[$i];
		}
	}
	die "no section: $section\n";
}

sub pop_section {
	my $self = shift;
	my $section = shift;
	
	for(my $i = 0; $i < $self->n_sections(); $i ++) {
		if($self->{section}->[$i]->{name} =~/$section/i) {
			if($i < $self->n_sections() - 1) {
				for(my $j = $i+1; $j < $self->n_sections(); $j ++) {
					$self->{section}->[$j-1] = $self->{section}->[$j]
				}
			}
			pop(@{$self->{section}});
			last;
		}
	}
	return($self);
}

# get the function name and its arguments
# also needs to check it is a S3method, S4mehtod or S4class
sub get_nearest_function_info {
	my $lines_ref = shift;
	my $index = shift;
	
	my $function_name;
	my $function_args;
	for(my $i = $index; $i < scalar(@$lines_ref); $i ++) {
		my $line = $lines_ref->[$i];
		
		# function should be defined as foo = function(...)
		if($line =~/([\S]+)\s*(=|<-)\s*function\s*\(/) {
			# then find the closing )
            $function_name = $1;
                  
            my $raw_args_str = $POSTMATCH;
            my $left_parenthese_flag = 1; # there are one unmatched left parenthese
            my $closing_position;
            if(($closing_position = find_closing_parenthese($raw_args_str, \$left_parenthese_flag)) > -1) {
                $function_args = substr($raw_args_str, 0, $closing_position);
            } else {
                $function_args = $raw_args_str;
                for($i ++; $i < scalar(@$lines_ref); $i ++) {
					$line = $lines_ref->[$i];
                    chomp $line;
                    $line =~s/^(\s+)//;
                    if(($closing_position = find_closing_parenthese($line, \$left_parenthese_flag)) > -1) {
                        $function_args .= substr($line, 0, $closing_position);
                        last;
                    }
                    $function_args .= " " x (length($function_name)+3) . $line . "\n";
                }
            }
            $function_name =~s/["']//g;
			$function_args = re_format_function_args($function_args);
			if(my ($g, $c) = check_generic_function($function_name)) {
				return ($function_name, "\\method{$g}{$c}($function_args)", "S3method", $c);
			} else {
				return ($function_name, "$function_name($function_args)", "");
			}
		} elsif($line =~/setMethod\(f\s*=\s*['"](.*?)['"]/) {  # s4method
			$function_name = $1;
			$i ++; 
			$line = $lines_ref->[$i];
            chomp $line;
            $line =~/signature\s*=\s*['"](.*?)['"]/;
            my $c = $1;

            $i ++; 
			$line = $lines_ref->[$i];
            if($line =~/definition\s*=\s*function\s*\(/) {
	            my $raw_args_str = $POSTMATCH;
	            my $left_parenthese_flag = 1; # there are one unmatched left parenthese
	            my $closing_position;
	            if(($closing_position = find_closing_parenthese($raw_args_str, \$left_parenthese_flag)) > -1) {
	                $function_args = substr($raw_args_str, 0, $closing_position);
	            } else {
	                $function_args = $raw_args_str;
	                for($i ++; $i < scalar(@$lines_ref); $i ++) {
						$line = $lines_ref->[$i];
	                    chomp $line;
	                    $line =~s/^(\s+)//;
	                    if(($closing_position = find_closing_parenthese($line, \$left_parenthese_flag)) > -1) {
	                        $function_args .= substr($line, 0, $closing_position);
	                        last;
	                    }
	                    $function_args .= " " x (length($function_name)+3) . $line . "\n";
	                }
	            }
	            $function_args = re_format_function_args($function_args);
				return ($function_name, "\\S4method{$function_name}{$c}($function_args)", "S4method", $c);
			}

		} elsif($line =~/setClass\(['"](.*?)['"]/) {   # s4class
			return ($1, "$1(...)", "S4class", $1)
		}
	}
	
	return ();
}

sub re_format_function_args {
	my $str = shift;
	my @str = split "\n", $str;
	for(my $i = 0; $i < scalar(@str); $i ++) {
		$str[$i] =~s/^\s+//;
		$str[$i] =~s/\s+$//;
		if($i > 0) {
			$str[$i] = "    $str[$i]";
		}
	}
	return(join "\n", @str);
}


# if find the closing parenthese, return the position in the string
# else return -1
sub find_closing_parenthese {
    my $str = shift;
    my $left_parenthese_flag = shift;
    my @args_char = split "", $str;

    for(my $i = 0; $i < scalar(@args_char); $i ++) {
        if($args_char[$i] eq "(") {
            $$left_parenthese_flag ++;
        }
        elsif($args_char[$i] eq ")") {
            $$left_parenthese_flag --;
        }

        if($$left_parenthese_flag == 0) {
            return $i;
        }
    }
    return -1;
}


# quite simple way, does not take consideration of the self-defined s3 generic method
sub check_generic_function {
	my $gf = {".__C_BindingFunction" => 1,
			".__C__derivedDefaultMethod" => 1,
			".__C__derivedDefaultMethodWithTrace" => 1,
			".__C__summaryDefault" => 1,
			"aggregate" => 1,
			"all.equal" => 1,
			"anyDuplicated" => 1,
			"aperm" => 1,
			"as.array" => 1,
			"as.character" => 1,
			"as.data.frame" => 1,
			"as.Date" => 1,
			"as.expression" => 1,
			"as.function" => 1,
			"as.list" => 1,
			"as.matrix" => 1,
			"as.null" => 1,
			"as.POSIXct" => 1,
			"as.POSIXlt" => 1,
			"as.single" => 1,
			"as.table" => 1,
			"barplot" => 1,
			"boxplot" => 1,
			"by" => 1,
			"chol" => 1,
			"confint" => 1,
			"contour" => 1,
			"cut" => 1,
			"default.stringsAsFactors" => 1,
			"defaultDumpName" => 1,
			"defaultPrototype" => 1,
			"density" => 1,
			"deriv" => 1,
			"deriv3" => 1,
			"diff" => 1,
			"duplicated" => 1,
			"finalDefaultMethod" => 1,
			"format" => 1,
			"format.summaryDefault" => 1,
			"hist" => 1,
			"image" => 1,
			"is.na<-" => 1,
			"kappa" => 1,
			"labels" => 1,
			"levels" => 1,
			"lines" => 1,
			"mean" => 1,
			"median" => 1,
			"merge" => 1,
			"model.frame" => 1,
			"model.matrix" => 1,
			"pairs" => 1,
			"plot" => 1,
			"points" => 1,
			"pretty" => 1,
			"print" => 1,
			"print.summaryDefault" => 1,
			"qqnorm" => 1,
			"qr" => 1,
			"quantile" => 1,
			"range" => 1,
			"residuals" => 1,
			"rev" => 1,
			"row.names" => 1,
			"row.names<-" => 1,
			"rowsum" => 1,
			"scale" => 1,
			"seq" => 1,
			"showDefault" => 1,
			"solve" => 1,
			"sort" => 1,
			"split" => 1,
			"split<-" => 1,
			"subset" => 1,
			"summary" => 1,
			"t" => 1,
			"terms" => 1,
			"text" => 1,
			"toString" => 1,
			"transform" => 1,
			"unique" => 1,
			"update" => 1,
			"with" => 1,
			"xtfrm" => 1,
			"+" => 1,
		};
	my $f = shift;
	foreach my $key (%$gf) {
		my $key2 = $key;
		if($key eq "+") {
			$key2 = "\\$key";
		}
		if($f =~/^$key2\.(\S+)$/) {
			return ($key, $1);
		}
	}
	return ();
}

sub sort {
	my $self = shift;

	# name, docType, alias, title, description, usage, arguments
	my $self2 = Storable::dclone($self);

	$self2->{section} = [];

	if($self->has_section("name")) {
		push(@{$self2->{section}}, $self->get_section("name"));
		$self->pop_section("name");
	}
	if($self->has_section("docType")) {
		push(@{$self2->{section}}, $self->get_section("docType"));
		$self->pop_section("docType");
	}
	while($self->has_section("alias")) {
		push(@{$self2->{section}}, $self->get_section("alias"));
		$self->pop_section("alias");
	}
	if($self->has_section("title")) {
		push(@{$self2->{section}}, $self->get_section("title"));
		$self->pop_section("title");
	}
	if($self->has_section("description")) {
		push(@{$self2->{section}}, $self->get_section("description"));
		$self->pop_section("description");
	}
	if($self->has_section("usage")) {
		push(@{$self2->{section}}, $self->get_section("usage"));
		$self->pop_section("usage");
	}
	if($self->has_section("arguments")) {
		push(@{$self2->{section}}, $self->get_section("arguments"));
		$self->pop_section("arguments");
	}

	if($self->n_sections() > 0) {
		push(@{$self2->{section}}, @{$self->{section}});
	}

	return $self2;
}

sub export_str {
	my $self = shift;

	my $page_type = $self->meta("page_type");
	if($page_type eq "S4class") {
		"exportClasses(".$self->meta("class").")";
	} elsif($page_type eq "S4method") {
		"exportMethods(".$self->meta("page_function").")";
	} elsif(!($page_type eq "data" || $page_type eq "package")) {
		"export(".$self->meta("page_function").")";
	} else {
		"";
	}
}


# some man file may exist
sub read_man_file {

	my $file = shift;

	if(! -e $file) {
		return undef;
	}

    open F, $file;

	my $text = join "", <F>;
	close F;

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
	

	if(scalar(@a) == 0) {
		return undef;
	}
	
	my $self = R::Hydrogen::Single->new();
	my $s;
	for(my $i = 0; $i < scalar(@a); $i += 3) {
		
		$a[$i + 2] =~s/^\{|\}$//g;
		$a[$i + 2] =~s/^\s*|\s*$//gs; # removing leading/tracing white space characters
		
		if($a[$i+1] eq "") {
			$s = R::Hydrogen::Section->new($a[$i]);
			$s->{tex} = $a[$i + 2];
		} else {
			$a[$i + 1] =~s/^\{|\}$//mg;
			$s = R::Hydrogen::Section->new($a[$i + 1]);
			$s->{tex} = $a[$i + 2];
		}
		
		push(@{$self->{section}}, $s);
	}
	
	return $self;
}

# align sections in two man files
sub combine {
	my $s1 = shift;
	my $s2 = shift;

	my $s3 = Storable::dclone($s1);
	$s3->{section} = [];

	my $nm1 = [ map { $_->{name} } @{$s1->{section}} ];
	my $nm2 = [ map { $_->{name} } @{$s2->{section}} ];

	my ($align1, $align2) = R::Hydrogen::Align::align($nm1, $nm2);

	# for(my $i = 0; $i < scalar(@$align1); $i ++) {
	# 	print "$align1->[$i]\t$align2->[$i]\n";
	# }
	
	my $s1_copy = Storable::dclone($s1);
	my $s2_copy = Storable::dclone($s2);

	my $alias = [];
	my $alias_name = {};
	for(my $i = 0; $i < scalar(@$align1); $i ++) {
		if($align1->[$i] eq "alias") {
			my $s1_alias_name = $s1_copy->get_section($align1->[$i])->{"tex"};
			if(! defined($alias_name->{$s1_alias_name}) ) {
				push(@$alias, $s1_copy->get_section($align1->[$i]));
				$s1_copy->pop_section($align1->[$i]);
				$alias_name->{$s1_alias_name} = 1;
			}
		}
		if($align2->[$i] eq "alias") {
			my $s2_alias_name = $s2_copy->get_section($align2->[$i])->{"tex"};
			if(! defined($alias_name->{$s2_alias_name}) ) {
				push(@$alias, $s2_copy->get_section($align2->[$i]));
				$s2_copy->pop_section($align2->[$i]);
				$alias_name->{$s2_alias_name} = 1;
			} else {
				$s2_copy->pop_section($align2->[$i]);
			}
		}
		if($align1->[$i] eq "alias" || $align2->[$i] eq "alias") {
			next;
		}

		if($align1->[$i] ne "") {
			push(@{$s3->{section}}, $s1->get_section($align1->[$i]));
		} elsif($align2->[$i] ne "") {
			push(@{$s3->{section}}, $s2->get_section($align2->[$i]));
		}
	}

	push(@{$s3->{section}}, @$alias);

	return($s3->sort());
}

sub S4method_dispatch {
	my $method = shift;
	my $class = shift;

	my $dispatch = R::Hydrogen::Single->new();
	$dispatch->meta("page_name" => "$method-dispatch");
	$dispatch->meta("page_type" => "");

	my $name = R::Hydrogen::Section->new("name");
	$name->{tex} = $dispatch->meta("page_name");
	push(@{$dispatch->{section}}, $name);

	my $alias = R::Hydrogen::Section->new("alias");
	$alias->{tex} = $method;
	push(@{$dispatch->{section}}, $alias);

	my $title = R::Hydrogen::Section->new("title");
	$title->{tex} = "Method dispatch page for $method";
	push(@{$dispatch->{section}}, $title);

	my $description = R::Hydrogen::Section->new("description");
	$description->{tex} = "Method dispatch page for $method";
	push(@{$dispatch->{section}}, $description);

	my $content = R::Hydrogen::Section->new("Dispatch");
	$content->{tex} = "\\code{$method} can be dispatched on following classes:\n\n";
	$content->{tex} .= "\\itemize{\n";
	for(my $i = 0; $i < scalar(@$class); $i ++) {
		$content->{tex} .= "\\item \\code{\\link{$method,$class->[$i]-method}}, \\code{$class->[$i]} class method\n";
	}
	$content->{tex} .= "}\n";
	push(@{$dispatch->{section}}, $content);

	return($dispatch);
}

1;