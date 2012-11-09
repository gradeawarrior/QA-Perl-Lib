=begin NaturalDocs

    This is a Utility module for commonly used operations used in  QA::Test libraries;
    it allows people to more easily and effectively write automated web tests that are
    specific to QA.
    
=cut
package QA::Test::Util;

use strict;
use Carp qw(croak);
use JSON::XS;
use XML::LibXML;
use XML::Simple;
use Test::More;
use POSIX;

=begin NaturalDocs

    Group: Copyright
	Copyright 2010, QA, All rights reserved.
    
    Author:
	Peter Salas
	
    About:

=cut

=begin NaturalDocs

    Group: Variables
    
    Pointer: $xml
	A reference to XML::Simple
    
=cut

my $xml = new XML::Simple (KeyAttr=>[]);

=begin NaturalDocs

    Group: Hash/Array Utilities
    
    Function: isArray
	Checks if a given reference is an ARRAY
    
    Parameters:
	arg - A reference
    
    Return:
	1 - (true) if arg is a reference to an ARRAY
	0 - (false) if arg is not a reference to an ARRAY

=cut

sub isArray #($arg)
{
    my ($self, $arg) = @_;
    ref($arg) eq 'ARRAY';
}

=begin NaturalDocs
    
    Function: isHash
	Checks if a given reference is an HASH
    
    Parameters:
	arg - A reference
    
    Return:
	1 - (true) if arg is a reference to an HASH
	0 - (false) if arg is not a reference to an HASH

=cut

sub isHash #($arg)
{
    my ($self, $arg) = @_;
    ref($arg) eq 'HASH';
}

=begin NaturalDocs
    
    Function: returnArray
	Returns an ARRAY reference if the given reference is not already an ARRAY
    
    Parameters:
	arg - A reference
    
    Return:
	ref - An array reference containing the original arg, if the arg is not already an ARRAY reference.

=cut

sub returnArray #($arg)
{
    my ($self, $arg) = @_;
    my @array;
    
    # Return undefined if $arg is undefined
    return $arg unless defined $arg;
    
    if ($self->isHash($arg)) {
        push(@array, $arg);
        return \@array;
    } elsif ($self->isArray($arg)) {
        return $arg;
    } else {
        push(@array, $arg);
	return \@array;
    }
}

=begin NaturalDocs
    
    Function: getEmptyHash
	Returns an empty HASH reference
    
    Return:
	ref - An empty HASH reference

=cut

sub getEmptyHash #()
{
    my $self = shift;
    return {};
}

=begin NaturalDocs
    
    Function: getEmptyArray
	Returns an empty ARRAY reference
    
    Return:
	ref - An empty ARRAY reference

=cut

sub getEmptyArray #()
{
    my $self = shift;
    return [];
}

=begin NaturalDocs

    Group: Object Intefaces
    
    Function: encodeJSON
	Uses JSON::XS to properly encode hash-array structures into a JSON string.
	
    Parameters:
	ref - A HASH/ARRAY reference
	pretty - (Optional) turns on/off pretty printing of JSON string. Default is 0 (false);
	
    Return:
	A JSON encoded string
    
=cut

sub encodeJSON #($ref, $pretty)
{
    my ($self, $ref, $pretty) = @_;
    
    croak "ref is undefined!" unless defined $ref;
    $pretty = 0 unless defined $pretty;
    my $coder;
    
    if ($pretty) {
	$coder = JSON::XS->new->ascii->pretty->allow_nonref;
	return $coder->encode($ref);
    } else {
	$coder = JSON::XS->new->ascii->allow_nonref;
	return $coder->encode($ref);
    }
}

=begin NaturalDocs

    
    Function: decodeJSON
	Uses JSON::XS to properly decode JSON string into hash-array structure.
	
    Parameters:
	json_str - A JSON string
	
    Return:
	A hash-array reference
    
=cut

sub decodeJSON #($json_str)
{
    my ($self, $json_str) = @_;
    croak "json_str is undefined!" unless defined $json_str;
    return decode_json($json_str);
}

=begin NaturalDocs

    Group: File Reader Utilities
    
    Function: convertXML
	Parses XML formatted data and returns a reference to a data structure which contains the same information in a more readily accessible form.
	It uses XML::Simple to parse a file or a string that represents XML.
	
    Parameters:
	file_string - STRING file path containing XML data
	
    Return:
	xml object - A hash-array reference containing xml data

=cut

sub convertXML #($file)
{
    my ($self, $file) = @_;
    
    return undef unless defined $file;
    return $xml->XMLin($file);
}

=begin NaturalDocs
    
    Function: changeToWindowsPath
	Converts all forward-slash '/' to back-slash '\'
	
    Parameters:
	path - STRING file path
	
    Return:
	windows file path - an approved windows file path with all foward-slash '/' converted to back-slash '\'

=cut

sub changeToWindowsPath #($str_path)
{
    my ($self, $path) = @_;
    
    $path =~ s/\//\\/g;
    return $path;
}

=begin NaturalDocs
    
    Function: changeToUnixPath
	Converts all back-slash '\' to forward-slash '/'
	
    Parameters:
	path - STRING file path
	
    Return:
	unix file path - an approved unix file path with all back-slash '\' converted to forward-slash '\'

=cut

sub changeToUnixPath #($str_path)
{
    my ($self, $path) = @_;
    
    $path =~ s/\\/\//g;
    return $path;
}

=begin NaturalDocs
    
    Function: validateXML_XSD
	Validates an XML against a given xsd file.
	
    Parameters:
	xml file - Either a file path to an xml, or a STRING containing xml
	xsd file - Either a file path to an xsd, or a STRING containing xsd
	
    Return:
	str - a STRING with an error message, or an empty STRING

=cut

sub validateXML_XSD #($xml_file, $xsd_file)
{
    my ($self, $xml_file, $xsd_file) = @_;
    
    croak 'xml_file was not defined!' unless defined $xml_file;
    croak 'xsd_file was not defined!' unless defined $xsd_file;
    
    my $doc = XML::LibXML->new->parse_file($xml_file);
    
    my $xmlschema = XML::LibXML::Schema->new( location => $xsd_file );
    eval { $xmlschema->validate( $doc ); };
    
    return $@;
}

=begin NaturalDocs

    Function: getFileName
	Retrieves the filename portion of fully qualified path.
    
    Parameters:
	file - A fully qualified file path
	enable_extension - (Optional) enables retrieval of the extension in addition to the filename. Default is 0 (false)
	
    Returns:
	file_name - The filename and its extension if enable_extension is set to 1 (true). If the file
	    is not found, then an empty string is returned

=cut

sub getFileName #($file, $enable_extension)
{
    my ($self, $file, $enable_extension) = @_;
    
    croak 'file is not defined!' unless defined $file;
    $enable_extension = QA::Test::Util->isTrue($enable_extension);
    
    # match a case where file is located on windows share and server is defined by IP address, e.g. \\10.18.34.82\qa-testdata\photo\myphoto.jpg
    if ($file =~ m/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(.*\\+)([A-Z,a-z,0-9_-]+)\.([A-Z,a-z,0-9]*)/g) {
	return $3 unless $enable_extension;
	return "$3.$4";
    }

    # all other matches...    
    if ($file =~ m/([A-Z,a-z,0-9_-]+)\.([A-Z,a-z,0-9]*)/g) {
	return $1 unless $enable_extension;
	return "$1.$2";
    } else {
	return "";
    }
}

=begin NaturalDocs

    Group: Boolean Verification
    
    Function: isTrue
	Checks whether given value (typically from an xml) is true.
	
    Parameters:
	value - any boolean value
    
    Returns:
	1 - (true) if value evaluates to true
	0 - (false) if value evaluates to false
	
    Note:
	The value could be in any of the following formats
	    - undef (null) ==> return 0
	    - true ==> return 1
	    - True ==> returns 1
	    - TRUE ==> returns 1
	    - 1 ==> returns 1
	    - false ==> returns 0
	    - False ==> returns 0
	    - FALSE ==> returns 0
	    - 0 ==> returns 0

=cut

sub isTrue #($value)
{
    my ($self, $value) = @_;
    
    ## Return 0 if not defined
    return 0 unless defined $value;
    
    ## Check if value is proper format
    if ($value =~ m/^true$/i) {
	return 1;
    } elsif ($value =~ m/^false$/i) {
	return 0;
    } elsif ($value =~ m/^[+-]?\d+$/ and $value == 1) {
	return 1;
    } elsif ($value =~ m/^[+-]?\d+$/ and $value == 0) {
	return 0;
    } else {
	diag(qq|\$value is not a valid type boolean (true/false or 1/0) - value:'$value' ref:|.ref($value));
	return 0;
    }
    
}

=begin NaturalDocs

    Group: Email
    
    Function: sendmail
	Simple sendmail wrapper
	
    Parameters:
	from - (Optional) The originator email, otherwise will use the system account
	reply_to - Email for receiver to reply back to
	send_to - List of emails (coma separated) of users to send email to
	subject - Email subject
	body - The email body. It supports html as well!
	content_type - (Optional) The MIME type of the content. By default this is set to "Content-type: text/html"
	verbose - (Optional) For debugging purposes and verifying that SENDMAIL is working
    
=cut

sub sendmail #(from=>'qa-team@ning.com', reply_to=>'peter@ning.com', send_to=>'alena@ning.com', subject=>'Test Subject', body=>'Test Body')
{   
    my ($self, %args) = @_;
    
    # Check Required variables
    croak 'reply_to is undefined!' unless defined $args{reply_to};
    croak 'send_to is undefined!' unless defined $args{send_to};
    croak 'subject is undefined!' unless defined $args{subject};
    croak 'body is undefined!' unless defined $args{body};
    
    # Setup sendmail variables
    my $sendmail = "/usr/sbin/sendmail -t"; # Path to the sendmail binary on the box
    my $reply_to = "Reply-to: $args{reply_to}\n";
    my $send_to  = "To: $args{send_to}\n";
    my $subject  = "Subject: $args{subject}\n";
    my $content_type;
    $content_type = "$args{content_type}\n\n" unless not defined $args{content_type};
    $content_type = "Content-type: text/html\n\n" unless defined $args{content_type};
    my $from = '';
    $from = "From: $args{from}\n" unless not defined $args{from};
    
    # Verbose Output
    print "Sending Mail...\n" unless not $args{verbose};
    print <<EOF unless not $args{verbose};

$sendmail
$from$send_to$reply_to$subject$content_type$args{body}
EOF
     
    # SendMail
    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
    print SENDMAIL $reply_to;
    print SENDMAIL $from;
    print SENDMAIL $send_to;
    print SENDMAIL $subject;
    print SENDMAIL $content_type;
    print SENDMAIL $args{body};
    close(SENDMAIL);
    
    print "Message Sent!\n";
    return 1;
}

return 1;