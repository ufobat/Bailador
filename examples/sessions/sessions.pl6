#!/usr/bin/env perl6

use v6.c;
use lib 'lib';
use Bailador;

config.cookie-expiration = 60 * 5; # 5minutes
config.hmac-key = 'my-key';

get '/' => sub {
    my $session = session;

    if ($session<user>:exists) {
        # ...
        # hello user
        return "Hello {$session<user>}";
    } else {
        #...
        # ask for user
        $session<user> = "ufobat";
        return "Whats your name?";
    }
}


baile;
