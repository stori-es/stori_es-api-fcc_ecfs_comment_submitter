# FCC Electronic Comment Filing System (ECFS) Comment Submitter

The [FCC's Electronic Comment Filing System (ECFS)](http://apps.fcc.gov/ecfs/) provides mechanisms for citizens and organizations to provide public input to the FCC.  This Ruby script automates the process of posting public comments collected through [the stori_es user generated content management system](https://github.com/stori-es/stori_es) into the [FCC's Express filing interface](http://apps.fcc.gov/ecfs/hotdocket/list).

## How It Works

This script uses the [stori_es API](https://github.com/stori-es/stori_es-api) to:

1. Retrieve Stories which have been gathered into a specified Collection in a stori_es instance
2. Transforms each Story into the comment format required by the FCC
3. Uses the [Mechanize gem](https://github.com/sparklemotion/mechanize) to submit each Story as a comment to the FCC's ECFS Express interface
4. Markup the Story with information returned by the FCC

## Requirements

This script utilizes the following Ruby gems:

* [rest-client](https://github.com/rest-client/rest-client)
* [json](https://github.com/flori/json)
* [mechanize](https://github.com/sparklemotion/mechanize)

You can [use Bundler](http://bundler.io/) to install the gems specified in the project gemfile.

## Status

This script should be regarded as alpha code which has been utilized in a production capacity but requires careful shepherding.  In particular, configuration settings must be hardcoded into the script itself and assumptions are made about the source Story data. YMMV and YHBW.

## License

This code is released under the [Apache v2.0 license](https://www.apache.org/licenses/LICENSE-2.0).
