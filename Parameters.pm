package Perl6::Parameters;

use 5.006;
use strict;
use warnings;
use Switch 'Perl6';		#given/when

our $VERSION = '0.02';

use Filter::Simple;

sub separate($);
sub makeproto(\@\@);
sub makepopstate(\@\@);

FILTER {
	while(/(sub\s+([\w:]+)\s*\(([^)]*\w.*?)\)\s*\{)/) {
		my($oldsubstate, $subname, $paramlist)=($1, $2, $3);
		my($substate);
		
		die "'is rw' is not implemented but is used in subroutine $subname" if($oldsubstate =~ /is rw/);
		
		#build the new sub statement
		do {
			my($popstate, $proto);
			
			do {
				#separate the parameter list into 3 arrays
				my(@ret)=separate($paramlist);
				my(@seps)=@{$ret[0]}; my(@params)=@{$ret[1]}; my(@names)=@{$ret[2]};

				#form the line-noise prototype
				($proto, my(@symbols))=makeproto(@params, @seps);
				
				#form the population statements
				$popstate=makepopstate(@names, @symbols);
			};

			#now assemble the new sub statement
			$substate="sub $subname ($proto) {\n\t$popstate"; warn "subname" unless defined $subname; warn "proto" unless defined $proto; warn "popstate" unless defined $popstate;
		};
		#$substate: DONE--contains the new sub statement

		#replace the old sub statement with the new one
		do {
			s/\Q$oldsubstate/$substate/;
		};
	}
	
	if(@_) {
		print STDERR $_ if($_[0] eq '-debug');
	}
};

sub separate($) {
	my($paramlist, @seps, @names, @params)=shift;
	my(@things);
	
	#split the param list on separators--but keep the separators around
	@things=split /([,;])/, $paramlist;

	#separate the things into separators and parameters
	for(0..$#things) {
		if($_ % 2) {
			push @seps, $things[$_];
		}
		else {
			push @params, $things[$_];
		}
	}

	#form the names array
	push @names, (/([\$\@\%]\w+)$/)[0] for @params;
	
	return \@seps, \@params, \@names;
}

sub makeproto(\@\@) {
	my($params, $seps)=@_;
	my(@symbols, $proto);
	
	#first, we convert each parameter to the appropriate symbol
	for(@$params) {
		push @symbols, tosymbol($_);
	}
	
	#then we get rid of commas since they don't appear in line-noise prototypes
	@$seps=map {$_ eq ',' ? "" : $_} @$seps;
	push @$seps, '';	#avoid warning
	
	#build the line-noise prototype
	$proto.="$symbols[$_]$seps->[$_]" for(0..$#symbols);
	
	return $proto, @symbols;
}

sub makepopstate(\@\@) {
	my(@names)=@{shift()};
	my(@symbols)=@{shift()};
	my($popstate);
		
	for(0..$#names) {
		given($symbols[$_]) {
			when '\@': {
				if($names[$_] =~ /\@/) {
					#literal array--use it
					$popstate .= "my($names[$_])=\@{shift()};\n";
				}
				else {
					#array ref--just like a normal one
					$popstate .= "my($names[$_])=shift;\n";
				}
			}
		
			when '\%': {
				if($names[$_] =~ m'%') {
					#literal hash--use it
					$popstate .= "my($names[$_])=\%{shift()};\n";
				}
				else {
					#hash ref--just like a normal one
					$popstate .= "my($names[$_])=shift;\n";
				}
			}
		
			when '@': {
				if($names[$_] ne '@_') {
					$popstate .= "my($names[$_])=(\@_);\n";
				}
			}
		
			when '%': {
				if($names[$_] eq '%_') {
					$popstate .= '(%_)=(@_);'
				}
				else {
					$popstate .= "my($names[$_])=(\@_);\n"
				}
			}
		
			$popstate .= "my($names[$_])=shift;\n";
		}
	}

	return $popstate;
}



sub tosymbol {
	my $term=shift;
	$term =~ s/^\s+|\s+$//g;	#strip whitespace

	given($term) {
				when /^REF/   : { return '\.' }		#Proposed in p5p, but NYI
		when /^GLOB/  : { return '\*' }
		when /^CODE/  : { return '&'  }
		when /^HASH/  : { return '\%' }
		when /^ARRAY/ : { return '\@' }
				when /^REGEXP/: { return '/'  }		#Proposed in p5p, but NYI
		when /^SCALAR/: { return '\$' }
		when /^\*\@/  : { return '@'  }
		when /^\*\%/  : { return '%'  }
		when /^\@/    : { return '\@' }
		when /^\%/    : { return '\%' }
		                { return '$'  }
	}
}

1;