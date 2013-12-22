## Parse UK Addresses

This project includes code that aims to help the parsing of UK addresses, as well as adding useful information to those addresses. It uses open data sources stored within a CouchDB database to provide geographical data that informs the address parsing and validation.

*Work in progress: Eventually this might be a service, but right now you can only run it locally. There are very likely to be errors, particularly in rural locations. Pull requests are very welcome, as are bug reports.*

### Data Sources

There are four main data sources that contain data from Ordnance Survey, Royal Mail and the Office of National Statistics and which have all been released under the OS Open Data licence or the Open Government Licence:

  * [CodePoint Open](http://www.ordnancesurvey.co.uk/business-and-government/products/code-point-open.html) contains information about postcodes, including their locations
  * [OS Locator](http://www.ordnancesurvey.co.uk/business-and-government/products/os-locator.html) contains information about roads within the UK
  * [1:50 000 Scale Gazetteer](http://www.ordnancesurvey.co.uk/business-and-government/products/50k-gazetteer.html) contains information about cities, towns and localities within the UK
  * [
Countries (2012) to government office regions (2010) to counties (2012) to local authority districts (2012) to wards (2012) UK lookup](https://geoportal.statistics.gov.uk/geoportal/catalog/search/resource/details.page?uuid=%7BB6A77A55-DB44-4C3C-901F-82742CB6A54B%7D) provides ONS codes for local authority districts and wards within the UK (codes used within CodePoint Open)

These are duplicated in the repo, but you should check to see that there haven't been any more recent releases and replace them as necessary.

### Requirements

 * Ruby 2.0.0

### Installation & Setup

1. Install [CouchDB](http://couchdb.apache.org/) and get it running (eg `couchdb -b`)
2. Edit `.env` for your setup
3. Do `bundle install` to get all the Ruby stuff set up properly
4. Run `rake upload` to load in all the relevant data to your local CouchDB
5. Run `cucumber -f progress features/parser.feature` to check everything's working

Note that it will take some time to run the tests the first time as CouchDB will need to index everything. Assuming normal local installation, you can check on CouchDB's status while it's indexing at [http://127.0.0.1:5984/_utils/status.html](http://127.0.0.1:5984/_utils/status.html).

### Using It

In your Ruby code (after requiring/loading the relevant file) you can do:

    parsed = AddressParser::Address.parse(address)

where `address` is a string that is the address (assumes comma-separated lines at the moment). `parsed` will be a hash with the appropriate ones of the following keys:

  * `:address` - the original address
  * `:postcode`
  * `:county`
  * `:city`
  * `:town`
  * `:locality`
  * `:estate` - the name of a business park or estate if one is mentioned
  * `:street`
  * `:dependent_street`
  * `:number`
  * `:name`
  * `:floor`
  * `:flat`
  * `:lines` - an array of additional lines, for example these might be organisation names or names of departments within a larger organisation
  * `:inferred` - another hash of information inferred from the address:
      * `:lat`
      * `:long`
      * `:latlong_source` - where the lat/long comes from, one of `:postcode`, `:city`, `:town`, `:locality` or `:street` and usually `:postcode`
      * `:pqi` - numeric position quality indicator from Codepoint Open where the location is identified through the postcode
      * `:district`
      * `:ward`
      * `:regional_health_authority`
      * `:health_authority`
  * `:errors` - a list of errors from parsing the address
  * `:warnings` - a list of warnings from parsing the address
  * `:unmatched` - any remaining string that was left over after parsing the address
      
Each of the inferred district, ward, regional health authority and health authority are further structured with:
      
  * `:_id` - ONS identifier
  * `:type` - ONS classification
  * `:full_name`
  * `:name`

Errors are:

  * `'ERR_NO_STREET'` when there's no detectable street within the address
  * `'ERR_NO_AREA'` when there's no detectable city, town or locality within the address
  * `'ERR_BAD_POSTCODE'` when the postcode is not within Codepoint Open
  * `'ERR_BAD_COUNTY'` when the county that has been supplied doesn't match the county for the town or locality provided in the address (this might happen if the county in the postcode is out of date)

Warnings are:

  * `'WARN_UNKNOWN_AREA'` when there's an area in the address that isn't listed within the OS Gazetteer
  * `'WARN_GUESSED_ESTATE'` when the parser guessed the name of a business park or industrial estate within the address
  * `'WARN_GUESSED_DEPENDENT_STREET'` when the parser guessed the name of a dependent street (which aren't listed in OS Locator) within the address

### Notes

  * OS Locator does not include all roads. In particular:
    * dependent streets (for example `Elm Avenue` in the address `6 Elm Avenue, Runcorn Road, Birmingham, B12 8QX`) are not listed within OS Locator, so they are matched purely through regular expression processing
    * other streets are simply missing for some reason (eg Carriage Drive in Windermere)
  * Industrial estates and business parks aren't listed anywhere, so these are matched through regular expression processing

### Rights and Licensing

[CodePoint Open](http://www.ordnancesurvey.co.uk/business-and-government/products/code-point-open.html) data within `data/codepo_gb.zip` is reproduced under the [OS Open Data Licence](http://www.ordnancesurvey.co.uk/docs/licences/os-opendata-licence.pdf): 

> Contains Ordnance Survey data © Crown copyright and database right 2013<br>
Contains Royal Mail data © Royal Mail copyright and database right 2013<br>
Contains National Statistics data © Crown copyright and database right 2013

[OS Locator](http://www.ordnancesurvey.co.uk/business-and-government/products/os-locator.html) data within `data/gazlco_gb.zip` is reproduced under the [OS Open Data Licence](http://www.ordnancesurvey.co.uk/docs/licences/os-opendata-licence.pdf): 

> Contains Ordnance Survey data © Crown copyright and database right 2013

[1:50 000 Scale Gazetteer](http://www.ordnancesurvey.co.uk/business-and-government/products/50k-gazetteer.html) data within `data/gaz50k_gb.zip` is reproduced under the [OS Open Data Licence](http://www.ordnancesurvey.co.uk/docs/licences/os-opendata-licence.pdf): 

> Contains Ordnance Survey data © Crown copyright and database right 2013

Lookup data within `data/ons.zip` is reproduced under the [Open Government Licence](http://www.nationalarchives.gov.uk/doc/open-government-licence):

> Contains National Statistics data © Crown copyright and database right 2013

[Property Addresses and Council Tax Valuation Bands](http://data.redbridge.gov.uk/View/property/property-addresses-and-council-tax-valuation-bands) from the [London Borough of Redbridge](http://www.redbridge.gov.uk/) within `data/redbridge.zip` is reproduced under the [Datashare Licence](http://data.redbridge.gov.uk/About/Licence).

Everything else is available under the MIT Licence:

Copyright (c) 2013 Open Data Institute

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.