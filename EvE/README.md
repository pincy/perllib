# EvE (libs)

For the API Documentation, please see
[evelopedia](https://wiki.eveonline.com/en/wiki/XML_API_Getting_Started), 
[3rd-party-documentation](https://eveonline-third-party-documentation.readthedocs.org/en/latest/), 
[eve-id api documentation](http://wiki.eve-id.net/APIv2_Page_Index).

In case you need more documentation, 
[Try some research](http://lmgtfy.com/?q=eve+online+api+documentation).

You can build the documentation with the included Doxyfile and 
[doxygen-filter-perl](https://github.com/jordan2175/doxygen-filter-perl).

### Eveapi

Lib for the XML API.

Example:
```
# import the library location
use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Eveapi;

# create an api object
my $api = EvE::Eveapi->new();
$api->loadFile("path/to/filename.json");

# the response will be an xml dom, you can traverse
my $response = $api->loadPath([ "account", "APIKeyInfo" ]);
my @cids;
foreach my $char ( @{ $response->{result}{key}{rowset}{row} } ) {
	print $char->{characterName}." {".$char->{characterID}."}\n";
	push(@cids, $char->{characterID});
}

# set the attribute
$api->attr( "characterID", $cids[0] );
# pull list of Industry Jobs
$response = $api->loadPath([ "char", "IndustryJobs" ]);
```

See the eveapi.pl for further example usage.

### Evecrest

Lib for the CREST API.

Example:
```
# import the library location
use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Eveapi;

# create an api object
my $api = EvE::Eveapi->new();

#lets load some data
my $items = $api->load_child_multipage({ name=> "itemGroups" });
```

See the BlueprintProcessor folder for further example usage.
```
# extract BPOs
BlueprintExtractor.pl -j > .itemgroupBPOs.json
# extraction can take quite a while... you should buffer the current data...

# show all BPOs for itemgroup 105
BlueprintProcessor.pl -f .BPOitemgroups.json 105
# show all BPOs in a started group, for the account key(s)
BlueprintProcessor.pl -f .BPOitemgroups.json -a ~/path_to/.apikeyfile
```

ToDo: License.


