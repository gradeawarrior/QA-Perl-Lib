package QA::Test::Mail::IMAP;

use strict;
use Time::HiRes qw(gettimeofday tv_interval);
use Carp qw(croak);
use Net::IMAP::Simple;
use Net::IMAP::Simple::SSL;
use Email::Simple;
use Test::More;
use QA::Test::Util::Boolean qw(isTrue);

###############
# Constructor #
###############

sub new {
    my($class, %args) = @_;
 
    croak '"QA::Test::Mail::IMAP Object Creation Error: server_address is mandatory!"' unless defined $args{server_address} or defined $class->{master_config}->{email_verification}->{server_address};
    croak '"QA::Test::Mail::IMAP Object Creation Error: server_port is mandatory!"' unless defined $args{server_port} or defined $class->{master_config}->{email_verification}->{server_port};
    croak '"QA::Test::Mail::IMAP Object Creation Error: server_email is mandatory!"' unless defined $args{server_email} or defined $class->{master_config}->{email_verification}->{server_email};
    croak '"QA::Test::Mail::IMAP Object Creation Error: server_password is mandatory!"' unless defined $args{server_password} or defined $class->{master_config}->{email_verification}->{server_password};
    croak '"QA::Test::Mail::IMAP Object Creation Error: server_folder_name is mandatory!"' unless defined $args{server_folder_name} or defined $class->{master_config}->{email_verification}->{server_folder_name};

    my $self = bless({}, $class);

    $self->{server_address} = $args{server_address};
    $self->{server_port} = $args{server_port};
    $self->{server_email} = $args{server_email};
    $self->{server_password} = $args{server_password};
    $self->{server_folder_name} = $args{server_folder_name};
    
    return $self;
}

sub getEmail {
    my ($self) = @_;
    
    my $imap;
    my $start_time = time;
    my $elapsed_time = 0;
    my $waitTime = 30; # In seconds
    
    $imap = Net::IMAP::Simple->new($self->{server_address}, 'port' => $self->{server_port}) || return (0, "Unable to connect to IMAP: $Net::IMAP::Simple::errstr");
    #$imap = Net::IMAP::Simple::SSL->new($self->{server_address}, 'port' => $self->{server_port}) || return (0, "Unable to connect to IMAP: $Net::IMAP::Simple::errstr");
    
    # Log in to the account
    if(!$imap->login($self->{server_email}, $self->{server_password})) {
	fail("Login failed on the email account used for verification");
	return (0, " Login failed: " . $imap->errstr . "\n")
    } else {
        pass("Successfully Logged-in");
    }

    
    my $message_count = $imap->select($self->{server_folder_name});
    diag("Message Count in '$self->{server_folder_name}': $message_count");
    
#    while ($elapsed_time <= $waitTime) {
#	
#	sleep(5);
#	
#	# Select Folder
#        my $message_count = $imap->select($self->{server_folder_name});	
#        for(my $i = 1; $i <= $message_count; $i++){
#            my $header = Email::Simple->new(join '', @{ $imap->top($i) } );
#	    #if ($header->header('Subject') =~ qr|$subject|i) {		
#	    if ($header->header('Subject') =~ qr|SPAM|i) {		
#		my $message = Email::Simple->new(join '', @{ $imap->get($i) } );
#		    #if($message->body=~qr|$verfication_number|i) {
#		    if($message->body=~qr|8888|i) {
#			pass("Email Verified");
#			return (1, $message->body);
#		    }
#            }
#        }
#	$elapsed_time = time - $start_time;
#    }

    $imap->quit;
    #fail("Email Not Verified");
    return (0, " ERROR: EMAIL NOT FOUND WITHIN $waitTime SECONDS!");
}

sub verifyEmail {
    
    my ($self,$subject,$verfication_number,$ssl_enabled) = @_;
    my $imap = '';
    my $start_time = time;
    my $elapsed_time = 0;
    my $waitTime = 30; # In seconds
    $ssl_enabled = isTrue($ssl_enabled);
    
    if (not $ssl_enabled)
        $imap = Net::IMAP::Simple->new($self->{server_address}, 'port' => $self->{server_port}) || return (0, "Unable to connect to IMAP: $Net::IMAP::Simple::errstr");
    } else {
        $imap = Net::IMAP::Simple::SSL->new($self->{server_address}, 'port' => $self->{server_port}) || return (0, "Unable to connect to IMAP: $Net::IMAP::Simple::errstr");
    }
    
    # Log in to the account
    if(!$imap->login($self->{server_email}, $self->{server_password})) {
	fail("Login failed on the email account used for verification");
	return (0, " Login failed: " . $imap->errstr . "\n")
    }; 

    diag(" Logged in to the Email Account.Waiting and Looking for the email with Subject : '$subject' and email body containing '$verfication_number'.");
    
    while ($elapsed_time <= $waitTime) {
	
	sleep(5);
	
	# Select Folder
        my $message_count = $imap->select($self->{server_folder_name});	
        for(my $i = 1; $i <= $message_count; $i++){
            my $header = Email::Simple->new(join '', @{ $imap->top($i) } );
	    if ($header->header('Subject') =~ qr|$subject|i) {		
		my $message = Email::Simple->new(join '', @{ $imap->get($i) } );
		    if($message->body=~qr|$verfication_number|i) {
			pass("Email Verified");
			return (1, $message->body);
		    }
            }
        }
	$elapsed_time = time - $start_time;
    }

    $imap->quit;
    fail("Email Not Verified");
    return (0, " ERROR: EMAIL NOT FOUND WITHIN $waitTime SECONDS!");

}

#==========#

=head1 AUTHOR

Peter Salas

=head1 COPYRIGHT

Copyright 2010-2011, QA Inc.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;
