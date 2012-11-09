=begin NaturalDocs
 
    This is part of the Test Runner Unit Test Framework which handles creation
    of a TestSuite.
 
=cut
package QA::Test::TestSuite;

use warnings;
use PPI;
use JSON;
use Carp qw(croak);

=begin NaturalDocs
 
    Group: Copyright
        Copyright 2010, QA, All rights reserved.
 
    Author:
        Peter Salas
 
	The concept of a TestSuite follows standard xUnit pattern. For more information on xUnit,
	see the following: http://en.wikipedia.org/wiki/XUnit
	
	You should create your Test by extending <QA::Test::TestCase>
	and define your 'test' subroutines by prefixing them with 'test_'. If
	you have a setup or teardown operation, then create a 'set_up' and
	'tear_down' subroutine.
 
=cut

=begin NaturalDocs
 
    Group: Variables
 
    Member Variables:
        test_cases - A HASH/ARRAY reference containing
	    <QA::Test::TestCase> classes and the 'test' methods to
	    execute within each class.
	cumalitive_test_cases - The total number of 'test', 'set_up', and
	    'tear_down' subroutine calls for all Test Classes. Note that
	    'set_up' and 'tear_down' will be called for every 'test' subroutine
	    within a class and cumalitive_test_cases includes these individual
	    calls.
 
=cut

=begin NaturalDocs
 
    Group: Constructor
 
    Function: new
        Constructor for instantiating <QA::Test::TestSuite>
 
    Parameters:
        None
 
    Returns:
        A blessed reference of <QA::Test::TestSuite>
	
    Example:
	(begin code)
	    my $test_suite = QA::Test::TestSuite->new();
	    foreach (@ARGV) {
		$test_suite->add_test_case_or_file($_, @test_methods);
	    }
	    foreach (@test_suites) {
		$test_suite->add_test_suite_from_file($_);
	    }
	(end)
 
=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    $self->{test_cases} = {};
    $self->{cumalitive_test_cases} = 0;
    bless($self, $class);
    return $self;
}

=begin NaturalDocs
 
    Group: Functions
 
    Function: add_test_case_or_file
        Adds a Test Class or a File that represents an instance of
	<QA::Test::TestCase>.
 
    Parameters:
        test_class_or_file - A package reference to a class, or the file path
	    that represents an instance of <QA::Test::TestCase>
	methods_to_run - An ARRAY containing a list of methods to execute. If
	    array is empty, then add to TestSuite all 'test_' methods.
 
    Returns:
        None
 
=cut

sub add_test_case_or_file #($test_class_or_file, @methods_to_run)
{
    my $self = shift;
    my $test_class_or_file = shift;
    my @methods_to_run = @_;

    my ($test_class, $test_module_name) = $self->load_test_class_file($test_class_or_file);

    # if test_class or test_module_name are not defined yet
    if (!defined $test_class || !defined $test_module_name) {
        ($test_class, $test_module_name) = $self->load_test_class($test_class_or_file);
    }

    # if test_class or test_module_name are still not defined
    if (!defined $test_class || !defined $test_module_name) {
        print STDERR "Could not find test class $test_class_or_file\n";
    }
    else {
	## Verify that test_class loaded successfully
	my $cmd = "perl -I".join(" -I", @INC)." $test_module_name";
        `$cmd`;
	croak "\n[ERROR] problem loading $test_class" if $? != 0;
	
	## Grab all test methods
	my @test_methods = grep(/^test_/, grep({defined &{"$test_class\::$_"}} sort keys %{"$test_class\::"}));

	## Add only user specified test methods (aka remove any that don't match regular expression)
	if (scalar @methods_to_run > 0) {
	    my @new_test_methods = ();

	    foreach (@methods_to_run) {
		my $filter = $_;
		foreach my $method (@test_methods) {
		    push(@new_test_methods, $method) if ($method =~ m/$filter/);
		}
	    }
	    @test_methods = @new_test_methods;
	}

	## Define Test Method associated with test_class
	my $testcase_methods = $self->{test_cases}->{$test_class};
	if (!defined $testcase_methods) {
	    $testcase_methods = {};
	    $self->{test_cases}->{$test_class} = $testcase_methods;
	}
	
	## Add test methods to run against test_class
	foreach (@test_methods) {
	    $testcase_methods->{$_} = $_;
	}
    }
    
    # Set the number of tests
    $self->count_test_cases();
}

=begin NaturalDocs

    Function: count_test_cases
	counts the number of methods to execute, including the number of times
	'set_up' and 'tear_down' will be called within a TestCase.
	
    Parameters:
	None
	
    Returns:
	The number of test cases for this TestSuite

=cut

sub count_test_cases {
    my $self = shift;
    my $bool = 0;
    $self->{cumalitive_test_cases} = 0;
    
    foreach (keys %{$self->{test_cases}}) {
	my $class = $_;
	$bool = 0;
	
	foreach (keys %{$self->{test_cases}->{$class}}) {
	    $self->{cumalitive_test_cases}+=1;
	    $bool=1;
	}
	
	if ($bool) {
	    if (defined &{"$_\::set_up"}) {
		$self->{cumalitive_test_cases}+=1;
	    }
	    if (defined &{"$_\::tear_down"}) {
		$self->{cumalitive_test_cases}+=1;
	    }
	}
    }
    
    return $self->{cumalitive_test_cases};
}

=begin NaturalDocs

    Function: get_test_cases
	Returns a sorted ARRAY of <QA::Test::TestCase> classes.
	
    Parameters:
	None
	
    Returns:
	An ARRAY ref of <QA::Test::TestCase> classes. They are not
	instantiated, and thus are only STRING's of the package name.

=cut

sub get_test_cases {
    my $self = shift;
    my @test_cases = sort(keys %{ $self->{test_cases} });
    return \@test_cases;
}

=begin NaturalDocs

    Function: get_test_methods_for_test_case
	Returns a sorted ARRAY of 'test' methods.
	
    Parameters:
	test_class - The test_class to retrieve 'test' methods to execute
	
    Returns:
	An ARRAY ref of <QA::Test::TestCase> methods.

=cut

sub get_test_methods_for_test_case {
	my ($self, $test_class) = @_;
    my $methods_hash = $self->{test_cases}->{$test_class};
    my $result = ();
    if (defined $methods_hash) {
        my @sorted_methods = sort( keys %{ $methods_hash } );
        $result = \@sorted_methods;
    }
    return $result;
}

=begin NaturalDocs

    Function: load_test_class
	Loads a Test Class and makes sure that directory is in @INC list
	
    Parameters:
	test_class - The test class package to load
	
    Returns:
	An ARRAY containing the test_class, and the file path where the module
	is located at. If the module fails to load, then an empty array is
	returned.

=cut

sub load_test_class {
    my $self = shift;
    my $test_class = shift;

    eval "require $test_class";

    my @tokens = split("::", $test_class);
    my $num_tokens = scalar @tokens;
    my $test_module_name = $tokens[$num_tokens - 1] . ".pm";
    if ($num_tokens > 1) {
            # using catfile here to generate correct paths on all supported envs
            $test_module_name = File::Spec->catfile(@tokens[0..($num_tokens - 2)], $test_module_name);
    }

    if ($INC{$test_module_name}) {
            return ($test_class, $test_module_name);
    }
    else {
            return ();
    }
}

=begin NaturalDocs

    Function: load_test_class_file
	Loads a Test Class File and makes sure that directory is in @INC list
	
    Parameters:
	test_class_file - The path to a Test Class file
	
    Returns:
	An ARRAY containing the test_class, and the file path where the module
	is located at.

=cut

sub load_test_class_file {
    my $self = shift;
    my $test_class_file = shift;

    # parse test_class_file and get package name, e.x. Ning::TestCase::Profile::get_screenname
    my $doc = PPI::Document->new($test_class_file);
    if (defined $doc) {
        my $packages = $doc->find(sub {$_[1]->isa('PPI::Statement::Package') and $_[1]->namespace() and $_[1]->file_scoped()});

        if (@$packages) {
            # we assume that Foo::Bar::baz.pm is a file <some folder>/Foo/Bar/baz.pm
            # we then need to split this absolute path into the module name (Foo/Bar/baz.pm) and the target directory to include
            # the latter we get from cutting the relevant number of directories (2 in the example, for Foo/Bar) off at the
            # end of the path of the directory containing the file
            my $test_class = $packages->[0]->namespace();
    
            # split test_class into tokens and get num_tokens
            my @tokens = split("::", $test_class);
            my $num_tokens = @tokens;
    
            # get module name by taking the last token and appending .pm
            my $test_module_name = $tokens[$num_tokens - 1] . ".pm";
    
            # construct the full path for the depth of the fully qualified test_module_name
            if ($num_tokens > 1) {
                $test_module_name = File::Spec->catfile(@tokens[0..($num_tokens - 2)], $test_module_name);
            }
    
            # extract volume, directories, file information from absolute path 
            my ($volume, $directories, $file) = File::Spec->splitpath(File::Spec->rel2abs($test_class_file));
            my @dirs = File::Spec->splitdir($directories);
            my $last_dir_to_keep = scalar(@dirs) - $num_tokens;
            if (@dirs[scalar @dirs - 1] eq "") {
                # @dirs might end in an empty string which corresponds to a trailing slash in $directories
                # but we don't care about the trailing slash ...
                $last_dir_to_keep--;
            }
                
            my $target_dir = File::Spec->catpath($volume, File::Spec->catdir(@dirs[0..$last_dir_to_keep]), "");

            push(@INC, $target_dir);
            eval "require $test_class";

            return ($test_class, $test_module_name);
        }
    }
    return ();
}

1;
