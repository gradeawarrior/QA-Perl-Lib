=begin NaturalDocs

    This is a utility method which is useful for performing text-replacement within a string even after
    the string was interpolated. It accomplishes this by searching for any variables delimited by double-percent (%)
    signs and uses the value between the percent signs as the 'key' in the vars hash reference parameter. The variable
    is then globally replaced by the 'value'.

=cut
package QA::Test::Util::TextReplacement;

use strict;
use Carp qw(croak);
use Exporter 'import';
use Test::More;

=begin NaturalDocs

    Group: Copyright
	Copyright 2010, QA, All rights reserved.
    
    Author:
	Peter Salas
	
    About:

=cut

=begin NaturalDocs
 
    Group: Variables
 
    ARRAY: @EXPORT_OK
        Export of all the functions in this package to the user space. You will
	need to explitly export these functions. Example:
	
	(begin code)
	use QA::Test::Util::Boolean qw(isTrue);
	(end)
    
    Constant: $REG_EXPRESSION
	Placeholder for a regular expression used in text replacement during post-interpolation of a STRING: qq|(%{2}[a-zA-Z0-9\_\-]+%{2})|;
 
=cut

my $REG_EXPRESSION = qq|(%{2}[a-zA-Z0-9\_\-]+%{2})|;

our @EXPORT = qw(checkTextReplaceString);
our @EXPORT_OK = qw(
    replaceText
);

=begin NaturalDocs

    Group: Text Replacement
    
    Function: replaceText
	Handy post interpolation text-replacement utility
	
	This is a utility method which is useful for performing text-replacement within a string even after
	the string was interpolated. It accomplishes this by searching for any variables delimited by double-percent (%)
	signs and uses the value between the percent signs as the 'key' in the vars hash reference parameter. The variable
	is then globally replaced by the 'value'.

	If there is no associated 'key' that corresponds to the variable, then the variable is replaced with 'NOT_DEFINED'.
	
    Parameters:
	str - This is some string that contains variables noted by double-percent signs which surround variable name
	vars - This is a hash reference to the variables to perform a text-replacement against
	random_str - (Optional) set if you have a variable %%random%% that you want to replace
	    with this string. The other option is to add it the 'vars' Hash reference keys with the value you
	    intend to replace with.
    
    Return:
	str - A converted string
    
    Exception:
	Note that there is a potential for an infinite loop to occur. To prevent this, this method is designed to
	'croak' if the number of variable replacements exceeds 10.
    
    Example:
	(begin code)
	    # hash variables
	    my $vars = {
		hello => 'world'
		user  => 'Peter'
	    }
	    
	    my $str = 'Hello %%user%%! You are Awesome';
	    $str = QA::Test::Util->replaceText($str, $vars);
	    print qq|\$str = '$str'\n|;
	    
	    my $str2 = "Title - %%random%%";
	    my $random_str = "Some Random String";
	    $str2 = QA::Test::Util->replaceText($str2, $vars, $random_str);
	    print qq|\$str2 = '$str2'\n|;
	    
	    #########################################
	    # Output: 				    #
	    # $str = 'Hello Peter! You are Awesome' #
	    # $str2 = 'Title - Some Random String'  #
	    #########################################
	(end)

=cut

sub replaceText #($str, $vars, $random_str)
{
    my ($str, $vars, $random_str) = @_;
    
    return $str unless defined $str;
    croak 'vars was not defined!' unless defined $vars;
    croak 'vars is not a hash reference!' unless QA::Test::Util->isHash($vars);
    
    my $limiter = 10;
    my $count = 0;
    while (checkTextReplaceString($str)) {
	if ($str =~ m/$REG_EXPRESSION/) {
	    my $var_str = $1; # The string without '%'
	    my $var_reg = $1; # The regular expression we're replacing in the form of: '%%some_text%%'
	    $var_str =~ s/%//g;
	    
	    if (defined $vars->{$var_str}) {
		$str =~ s/$var_reg/$vars->{$var_str}/g;
	    } elsif (defined $random_str and $var_str =~ m/^random$/i) {
		$str =~ s/$var_reg/$random_str/g;
	    } else {
		$str =~ s/$var_reg/NOT_DEFINED/g;
	    }
	}
	
	$count++;
	croak "Infinite loop detected. exiting because cannot iterate more than $limiter time(s): '$str' =~ m/$REG_EXPRESSION/i" unless ($count < $limiter);
    }
    
    return $str;
}

=begin NaturalDocs

    Function checkTextReplaceString
	checks whether the string contains a variable delimited by double-percent (%) signs.
	
    Parameters:
	str - This is some string that contains variable index delimited by double-percent signs around variable name
	
    Return:
	1 - (true) if variable found within STRING
	0 - (false) if no variable found

=cut

sub checkTextReplaceString #($str)
{
    my ($str) = @_;
    return ($str =~ m/$REG_EXPRESSION/);
}

1;
