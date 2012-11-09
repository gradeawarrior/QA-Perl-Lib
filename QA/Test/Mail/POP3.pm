package QA::Test::Mail::POP3;

use strict;
use Net::POP3;

# Constructors
my $pop = Net::POP3->new('pop3host');
$pop = Net::POP3->new('pop3host', Timeout => 60);
my $username="foo";
my $password="bar";

if ($pop->login($username, $password) > 0) {
    my $msgnums = $pop->list; # hashref of msgnum => size
    foreach my $msgnum (keys %$msgnums) {
        my $msg = $pop->get($msgnum);
        print @$msg;
        $pop->delete($msgnum);
    }
}

$pop->quit;