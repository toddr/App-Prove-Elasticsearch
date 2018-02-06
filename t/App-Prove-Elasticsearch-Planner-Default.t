use strict;
use warnings;

use Test::More tests => 14;
use Test::Deep;
use Test::Fatal;

use App::Prove::Elasticsearch::Planner::Default;

INDEXER: {
    no warnings qw{redefine once};
    local *Search::Elasticsearch::new = sub { return bless({},'Search::Elasticsearch') };
    local *Search::Elasticsearch::indices = sub { return bless({},'Search::Elasticsearch::Indices') };
    local *Search::Elasticsearch::Indices::exists = sub { return 1};
    use warnings;

    like(exception { App::Prove::Elasticsearch::Planner::Default::check_index() }, qr/server must be specified/i,"Indexer dies in the event server & port  is not specified");
    like(exception { App::Prove::Elasticsearch::Planner::Default::check_index({ 'server.port' => 666 }) }, qr/server must be specified/i,"Indexer dies in the event server are not specified");
    like(exception { App::Prove::Elasticsearch::Planner::Default::check_index({ 'server.host' =>'zippy.test' }) }, qr/port must be specified/i,"Indexer dies in the event port is not specified");

    is(App::Prove::Elasticsearch::Planner::Default::check_index({ 'server.host' => 'zippy.test', 'server.port' => 666}),0,"Indexer skips indexing in the event index already exists.");

    no warnings qw{redefine once};
    local *Search::Elasticsearch::Indices::exists = sub { return 0 };
    local *Search::Elasticsearch::Indices::create = sub { };
    use warnings;

    is(App::Prove::Elasticsearch::Planner::Default::check_index({ 'server.host' => 'zippy.test', 'server.port' => 666 }),1,"Indexer runs in the event index nonexistant.");
}

GET_PLAN: {
    #options: version must be set, platforms and name must be tested independently

    no warnings qw{redefine once};
    local *Search::Elasticsearch::search = sub { return undef };
    use warnings;
    $App::Prove::Elasticsearch::Planner::Default::e = bless({},'Search::Elasticsearch');

    #check version must be set
    like(exception { App::Prove::Elasticsearch::Planner::Default::get_plan()}, qr/version/ , "Not passing version fails to get plan");
    is(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666), 0, "get_plan: Bogus return from Search::Elasticsearch->search() returns false");


    my $ret = { hits => { hits => [] } };

    no warnings qw{redefine once};
    local *Search::Elasticsearch::search = sub { return $ret };
    use warnings;
    is(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666), 0, "get_plan: Empty return from Search::Elasticsearch->search() returns false");

    #check version alone may be passed
    $ret->{hits}{hits} = [
        {
            _source => {
                platforms => 'shoes',
                name      => 'zippyPlan',
                version   => 666,
                id        => 420,
            },
            _id => 420,
        }
    ];
    is_deeply(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666), $ret->{hits}{hits}->[0]->{_source}, "get_plan returns first matching plan ");

    #check name + version works
    is_deeply(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666, name => 'zippyPlan'), $ret->{hits}{hits}->[0]->{_source}, "get_plan returns first name matching plan ");
    is(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666, name => 'bogusPlan'), 0, "get_plan returns no plan when bogus name match returned");

    #check platforms + version works
    is_deeply(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666, platforms => ['shoes'] ), $ret->{hits}{hits}->[0]->{_source}, "get_plan returns first platform matching plan ");
    is(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666, platforms => ['socks'] ), 0, "get_plan returns no plan when bogus platform match returned");
    is(App::Prove::Elasticsearch::Planner::Default::get_plan(version => 666, platforms => ['socks','shoes'] ), 0, "get_plan returns no plan when insufficient platform match returned");

}


