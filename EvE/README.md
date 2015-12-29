# EvE (libs)

For the API Documentation, please see
[evelopedia](https://wiki.eveonline.com/en/wiki/XML_API_Getting_Started), 
[3rd-party-documentation](https://eveonline-third-party-documentation.readthedocs.org/en/latest/), 
[eve-id api documentation](http://wiki.eve-id.net/APIv2_Page_Index).

In case you need more documentation, 
[Try some research](http://lmgtfy.com/?q=eve+online+api+documentation).

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

### Evecrest

Lib for the CREST API.

Example:
```
# import the library location
use lib $ENV{CUSTOM_PERL_LIB};

use EvE::Eveapi;

# create an api object
my $api = EvE::Eveapi->new();

```

ToDo: further documentation and generate docs
