
=head1 DESCRIPTION

This test ensures that the OpenAPI spec produced by Yancy is correct and the
API routes work as expected.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use v5.24;
use experimental qw( signatures postderef );
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );

use Yancy::Backend::Test;
%Yancy::Backend::Test::COLLECTIONS = (
    people => {
        1 => {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        2 => {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    },
    users => {
        doug => {
            username => 'doug',
            email => 'doug@example.com',
        },
        joel => {
            username => 'joel',
            email => 'joel@example.com',
        },
    },
);

$ENV{MOJO_CONFIG} = path( $Bin, '/share/config.pl' );

my $t = Test::Mojo->new( 'Yancy' );

subtest 'fetch generated OpenAPI spec' => sub {
    $t->get_ok( '/yancy/api' )
      ->status_is( 200 )
      ->content_type_like( qr{^application/json} )
      ->json_is( '/definitions/peopleItem' => $t->app->config->{collections}{people} )
      ->json_is( '/definitions/usersItem' => $t->app->config->{collections}{users} )

      ->json_has( '/paths/~1people/get/responses/200' )
      ->json_has( '/paths/~1people/get/responses/default' )

      ->json_has( '/paths/~1people/post/parameters' )
      ->json_has( '/paths/~1people/post/responses/201' )
      ->json_has( '/paths/~1people/post/responses/400' )
      ->json_has( '/paths/~1people/post/responses/default' )

      ->json_has( '/paths/~1people~1{id}/parameters' )
      ->json_has( '/paths/~1people~1{id}/get/responses/200' )
      ->json_has( '/paths/~1people~1{id}/get/responses/404' )
      ->json_has( '/paths/~1people~1{id}/get/responses/default' )

      ->json_has( '/paths/~1people~1{id}/put/parameters' )
      ->json_has( '/paths/~1people~1{id}/put/responses/200' )
      ->json_has( '/paths/~1people~1{id}/put/responses/404' )
      ->json_has( '/paths/~1people~1{id}/put/responses/default' )

      ->json_has( '/paths/~1people~1{id}/delete/responses/204' )
      ->json_has( '/paths/~1people~1{id}/delete/responses/404' )
      ->json_has( '/paths/~1people~1{id}/delete/responses/default' )
      ;
};

subtest 'fetch list' => sub {
    $t->get_ok( '/yancy/api/people' )
      ->status_is( 200 )
      ->json_is( {
            rows => [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 1 2 )} ],
            total => scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
        } );

    subtest 'limit/offset' => sub {
        $t->get_ok( '/yancy/api/people?limit=1' )
          ->status_is( 200 )
          ->json_is( {
                rows => [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 1 )} ],
                total => scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
            } );

        $t->get_ok( '/yancy/api/people?offset=1' )
          ->status_is( 200 )
          ->json_is( {
                rows => [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 2 )} ],
                total => scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
            } );
    };

    subtest 'order_by' => sub {

        $t->get_ok( '/yancy/api/people?order_by=asc:name' )
          ->status_is( 200 )
          ->json_is( {
                rows => [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 1 2 )} ],
                total => scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
            } );

        $t->get_ok( '/yancy/api/people?order_by=desc:name' )
          ->status_is( 200 )
          ->json_is( {
                rows => [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 2 1 )} ],
                total => scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
            } );

    };
};

subtest 'fetch one' => sub {
    $t->get_ok( '/yancy/api/people/1' )
      ->status_is( 200 )
      ->json_is( $Yancy::Backend::Test::COLLECTIONS{people}{1} );
    $t->get_ok( '/yancy/api/users/doug' )
      ->status_is( 200 )
      ->json_is( $Yancy::Backend::Test::COLLECTIONS{users}{doug} );
};

subtest 'set one' => sub {
    my $new_person = { name => 'Foo', email => 'doug@example.com', id => 1 };
    $t->put_ok( '/yancy/api/people/1' => json => $new_person )
      ->status_is( 200 )
      ->json_is( $new_person );
    is_deeply $Yancy::Backend::Test::COLLECTIONS{people}{1}, $new_person;

    my $new_user = { username => 'doug', email => 'douglas@example.com' };
    $t->put_ok( '/yancy/api/users/doug' => json => $new_user )
      ->status_is( 200 )
      ->json_is( $new_user );
    is_deeply $Yancy::Backend::Test::COLLECTIONS{users}{doug}, $new_user;
};

subtest 'add one' => sub {
    my $new_person = { name => 'Flexo', email => 'flexo@example.com', id => 3 };
    $t->post_ok( '/yancy/api/people' => json => $new_person )
      ->status_is( 201 )
      ->json_is( $new_person )
      ;
    is_deeply $Yancy::Backend::Test::COLLECTIONS{people}{3}, $new_person;

    my $new_user = { username => 'flexo', email => 'flexo@example.com' };
    $t->post_ok( '/yancy/api/users' => json => $new_user )
      ->status_is( 201 )
      ->json_is( $new_user );
    is_deeply $Yancy::Backend::Test::COLLECTIONS{users}{flexo}, $new_user;
};

subtest 'delete one' => sub {
    $t->delete_ok( '/yancy/api/people/3' )
      ->status_is( 204 )
      ;
    ok !exists $Yancy::Backend::Test::COLLECTIONS{people}{3}, 'person 3 not exists';

    $t->delete_ok( '/yancy/api/users/flexo' )
      ->status_is( 204 )
      ;
    ok !exists $Yancy::Backend::Test::COLLECTIONS{users}{flexo}, 'flexo not exists';
};

done_testing;
