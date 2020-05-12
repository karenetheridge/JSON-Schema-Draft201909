use strict;
use warnings;

use Test::More;
use Test::Fatal;
use JSON::Schema::Draft201909;

my $js = JSON::Schema::Draft201909->new;

foreach my $keyword (qw($id $anchor $recursiveRef $recursiveAnchor $vocabulary)) {
  like(
    exception { $js->evaluate('hello', { $keyword => 'something' }) },
    qr/^unsupported keyword "\Q$keyword\E"/,
    'presence of unsupported keyword "'.$keyword.'" results in an exception',
  );
}

done_testing;