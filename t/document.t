use strict;
use warnings;
no if "$]" >= 5.031009, feature => 'indirect';
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8

use Test::More 0.88;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::Deep::UnorderedPairs;
use Test::Fatal;
use JSON::Schema::Draft201909::Document;
use lib 't/lib';
use Helper;

subtest 'boolean document' => sub {
  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(schema => false),
    listmethods(
      resource_index => [
        '' => {
          path => '',
          canonical_uri => str(''),
        },
      ],
      canonical_uri => [ str('') ],
    ),
    'boolean schema with no canonical_uri',
  );

  like(
    exception {
      JSON::Schema::Draft201909::Document->new(
        canonical_uri => Mojo::URL->new('https://foo.com#/x/y/z'),
        schema => false,
      )
    },
    qr/canonical_uri cannot contain a fragment/,
    'boolean schema with invalid canonical_uri',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      canonical_uri => Mojo::URL->new('https://foo.com'),
      schema => false,
    ),
    listmethods(
      resource_index => [
        'https://foo.com' => {
          path => '',
          canonical_uri => str('https://foo.com'),
        },
      ],
      canonical_uri => [ str('https://foo.com') ],
    ),
    'boolean schema with valid canonical_uri',
  );
};

subtest 'object document' => sub {
  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(schema => {}),
    listmethods(
      resource_index => [
        '' => {
          path => '',
          canonical_uri => str(''),
        },
      ],
      canonical_uri => [ str('') ],
    ),
    'object schema with no canonical_uri, no root $id',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      canonical_uri => Mojo::URL->new('https://foo.com'),
      schema => {},
    ),
    listmethods(
      resource_index => [
        # note: no '' entry!
        'https://foo.com' => {
          path => '',
          canonical_uri => str('https://foo.com'),
        },
      ],
      canonical_uri => [ str('https://foo.com') ],
    ),
    'object schema with valid canonical_uri, no root $id',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => { '$id' => 'https://bar.com' },
    ),
    listmethods(
      resource_index => [
        # note: no '' entry!
        'https://bar.com' => {
          path => '',
          canonical_uri => str('https://bar.com'),
        },
      ],
      canonical_uri => [ str('https://bar.com') ], # note canonical_uri has been overwritten
    ),
    'object schema with no canonical_uri, and absolute root $id',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      canonical_uri => Mojo::URL->new('https://foo.com'),
      schema => {
        '$id' => 'https://bar.com',
        allOf => [
          { '$anchor' => 'my_anchor' },
          { '$id' => 'x/y/z.json' },
        ],
      },
    ),
    listmethods(
      resource_index => unordered_pairs(
        'https://foo.com' => {  # the originally-provided uri is only used for the root schema
          path => '',
          canonical_uri => str('https://bar.com'),
        },
        'https://bar.com' => {
          path => '',
          canonical_uri => str('https://bar.com'),
        },
        'https://bar.com#my_anchor' => {
          path => '/allOf/0',
          canonical_uri => str('https://bar.com#/allOf/0'),
        },
        'https://bar.com/x/y/z.json' => {
          path => '/allOf/1',
          canonical_uri => str('https://bar.com/x/y/z.json'),
        },
      ),
      canonical_uri => [ str('https://bar.com') ],
    ),
    'object schema with canonical_uri and root $id, and additional resource schemas as well',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => {
        '$defs' => {
          foo => {
            '$id' => 'my_foo',
            const => 'foo value',
          },
        },
        '$ref' => 'my_foo',
      },
    ),
    listmethods(
      resource_index => unordered_pairs(
        '' => { path => '', canonical_uri => str('') },
        'my_foo' => {
          path => '/$defs/foo',
          canonical_uri => str('my_foo'),
        },
      ),
    ),
    'relative uri for root $id',
  );

  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => {
        '$defs' => {
          foo => {
            '$id' => 'http://localhost:4242/my_foo',
            const => 'foo value',
          },
        },
      },
    ),
    listmethods(
      resource_index => unordered_pairs(
        '' => { path => '', canonical_uri => str('') },
        'http://localhost:4242/my_foo' => {
          path => '/$defs/foo',
          canonical_uri => str('http://localhost:4242/my_foo'),
        },
      ),
    ),
    'no root $id; absolute uri with path in subschema resource',
  );
};

subtest '$id and $anchor as properties' => sub {
  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => {
        type => 'object',
        properties => {
          '$id' => { type => 'string' },
          '$anchor' => { type => 'string' },
        },
      },
    ),
    listmethods(
      resource_index => [
        '' => { path => '', canonical_uri => str('') },
      ],
    ),
    'did not index the $id and $anchor properties as if they were identifier keywords',
  );
};

subtest '$id with an empty fragment' => sub {
  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => {
        '$defs' => {
          foo => {
            '$id' => 'http://localhost:4242/my_foo#',
            type => 'string',
          },
        },
      },
    ),
    listmethods(
      resource_index => unordered_pairs(
        '' => { path => '', canonical_uri => str('') },
        'http://localhost:4242/my_foo' => {
          path => '/$defs/foo',
          canonical_uri => str('http://localhost:4242/my_foo'),
        },
      ),
    ),
    '$id is stored with the empty fragment stripped',
  );
};

subtest '$id with a non-empty fragment' => sub {
  cmp_deeply(
    JSON::Schema::Draft201909::Document->new(
      schema => {
        '$defs' => {
          foo => {
            '$id' => 'http://localhost:4242/my_foo#hello',
            type => 'string',
          },
        },
      },
    ),
    listmethods(
      resource_index => [
        '' => { path => '', canonical_uri => str('') },
      ],
    ),
    'did not index the $id with a non-empty fragment -- either it is not in a subschema or the schema is buggy',
  );
};

done_testing;