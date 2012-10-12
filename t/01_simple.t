use strict;
use warnings;
use utf8;
use Test::More;
use HTTP::Message::PSGI;
use HTTP::Request::Common;
use HTTP::Response;

{
    package MyApp::Web;
    use Amon2::Web::JSONAPI -DFV;

    get '/api/get' => +{
        required => [qw/x y/],
    }, sub {
        my ($c, $args, $valids) = @_;
        return +{
            result => $valids->{x} + $valids->{y}
        };
    };

    get '/api/args/:id' => +{
    }, sub {
        my ($c, $args, $valids) = @_;
        return +{
            result => $args->{id}
        };
    };

    # method testing.
    get '/api/method/get' => +{ }, sub {
        return +{ "OK" => 1 };
    };
    post '/api/method/post' => +{ }, sub {
        return +{ "OK" => 1 };
    };
    any '/api/method/any' => +{ }, sub {
        return +{ "OK" => 1 };
    };

    # array testing
    get '/api/array' => sub {
        return [1,2,3];
    };

    # rule is optional
    get '/api/optional/get' => sub {
        return +{};
    };
    post '/api/optional/post' => sub {
        return +{};
    };
    any '/api/optional/any' => sub {
        return +{};
    };
}

sub run {
    my $req = shift;
    my $app = MyApp::Web->to_app();
    my $res = res_from_psgi($app->(req_to_psgi $req));
    is($res->content_type, 'application/json', 'Content-Type is always json.');
    return $res;
}

subtest 'simple' => sub {
    subtest 'fail' => sub {
        my $res = run GET 'http://example.com/api/get';
        is($res->code, 400);
        is($res->content, '{"error":{"missings":["y","x"],"invalids":[]}}');
    };

    subtest 'success' => sub {
        my $res = run GET 'http://example.com/api/get?y=3&x=5';
        is($res->code, 200);
        is($res->content, '{"result":8}');
    };

    subtest 'Router::Simple capture' => sub {
        my $res = run GET 'http://example.com/api/args/4649';
        is($res->code, 200);
        is($res->content, '{"result":"4649"}');
    };
};

subtest 'not found' => sub {
    my $res = run(GET 'http://example.com/invalid_path');
    is($res->code, 404);
};

subtest 'method not allowed' => sub {
    subtest 'get' => sub {
        subtest 'allow' => sub {
            my $res = run(GET 'http://example.com/api/method/get');
            is($res->code, 200);
        };
        subtest 'not allowed' => sub {
            my $res = run(POST 'http://example.com/api/method/get');
            is($res->code, 405);
            is($res->message, 'Method Not Allowed');
        };
    };
    subtest 'post' => sub {
        subtest 'allow' => sub {
            my $res = run(POST 'http://example.com/api/method/post');
            is($res->code, 200);
        };
        subtest 'not allowed' => sub {
            my $res = run(GET 'http://example.com/api/method/post');
            is($res->code, 405);
            is($res->message, 'Method Not Allowed');
        };
    };
    subtest 'any' => sub {
        subtest 'allow' => sub {
            my $res = run(POST 'http://example.com/api/method/any');
            is($res->code, 200);
        };
        subtest 'And, allowed' => sub {
            my $res = run(GET 'http://example.com/api/method/any');
            is($res->code, 200);
        };
    };
};

subtest 'array response' => sub {
    subtest 'croaks' => sub {
        eval {
            run(GET 'http://example.com/api/array');
        };
        like($@, qr/hijacking/);
    };
    subtest 'Allows if users accept security issue' => sub {
        local $Amon2::Web::JSONAPI::ALLOW_JSON_HIJACKING = 1;
        my $res = run(GET 'http://example.com/api/array');
        is($res->code, 200);
        is($res->content, '[1,2,3]');
    };
};

subtest 'rule is optional' => sub {
    subtest 'get' => sub {
        my $res = run(GET 'http://example.com/api/optional/get');
        is($res->code, 200);
    };
    subtest 'post' => sub {
        my $res = run(POST 'http://example.com/api/optional/post');
        is($res->code, 200);
    };
    subtest 'any' => sub {
        my $res = run(POST 'http://example.com/api/optional/any');
        is($res->code, 200);
    };
};

done_testing;

