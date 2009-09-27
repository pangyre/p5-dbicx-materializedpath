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

for my $new ( 1 .. 5 )
{
    sleep 1;
    ok( my $kid = $schema->resultset("TreeData")->create({ content => "Kid #$new",
                                                           created => $NOW }),
        "Creating a new record"
      );

#    ok( $node->add_to_children($kid),
#        );
}


__END__

