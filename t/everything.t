use Test::More "no_plan";
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestSchema;
use DBICx::TestDatabase;

my $NOW = \"datetime('now')"; # "

ok( my $schema = DBICx::TestDatabase->new("TestSchema"),
    'Instantiating DBICx::TestDatabase->new("TestSchema")'
    );

# id, parent, content, created
ok( my $node = $schema->resultset("TreeData")->create({ content => "OH HAI",
                                                        created => $NOW }),
    "Creating a record"
    );

# use YAML; diag(YAML::Dump({$node->get_columns}));
#ok( $node->update );
# use YAML; diag(YAML::Dump({$node->get_columns}));

is( $node->path, $node->id,
    "The path and the id are the same value for root nodes" );

my $last = $node;
my $subtests = 0;
for my $new ( 1 .. 3 )
{
    ok( my $kid = $schema->resultset("TreeData")->create({ content => "Kid #$new",
                                                           parent => $last,
                                                           created => $NOW }),
        "Creating a new record"
      );

    is( $kid->node_depth, $new + 1,
        "Node depth " . ( $new + 1 ) . " is right" );

    ok( my @ancestors = $kid->ancestors,
        "Getting ancestors" );

    cmp_ok( scalar(@ancestors), "==", $new,
            sprintf("Ancestor count for record %s (path:%s) is sensible",
                    $kid->id, $kid->path )
          );


    my @sorted = sort { length($a->path) <=> length($b->path) } @ancestors;

    is_deeply( \@sorted, \@ancestors,
               "Ancestors are returned in appropriate order" );

    $last = $kid;
}

diag( "MOOOO " . $last->path );

__END__


    for my $ancestor ( $kid->ancestors )
    {
        
    }
