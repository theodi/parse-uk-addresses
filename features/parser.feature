Feature: UK address parsing
  In order to make a useful address database
  As a developer
  I want to break down an address into its component parts so that it's easier to reason over

  Scenario: Parsing a simple address
    When I parse the address Open Data Institute, 3rd Floor, 65 Clifton Street, London EC2A 4JE
    Then I get an address whose postcode is EC2A 4JE
     And whose city is London
     And whose street is Clifton Street
     And whose number is 65
     And whose floor is 3rd Floor
     And whose first line is Open Data Institute
     And whose inferred lat is the float 51.52238743450444
     And whose inferred long is the float -0.08364849577490492
     And whose inferred district name is Hackney
     And whose inferred ward name is Haggerston
     And whose inferred regional_health_authority name is London Programme for IT (LPFiT)
     And whose inferred health_authority name is London

  Scenario: Parsing another address with a separate postcode
    When I parse the address 92, Liston Way, Woodford Green, Essex IG8 7BL
    Then I get an address whose postcode is IG8 7BL
     And whose county is Essex
     And has no city
     And whose locality is Woodford Green
     And whose street is Liston Way
     And whose number is 92
     And has no floor
     And has no line1

  Scenario: Parsing an address where the town is a fair distance from the location
    When I parse the address 88 Briarwood Road, Epsom KT17 2NG
    Then I get an address whose town is Epsom
     And whose street is Briarwood Road
     And whose number is 88

# The following scenarios with thanks to http://www.mjt.me.uk/posts/falsehoods-programmers-believe-about-addresses/

  Scenario: Parsing an address without a number
    When I parse the address Royal Opera House, Covent Garden, London, WC2E 9DD
    Then I get an address whose postcode is WC2E 9DD
     And whose city is London
     And whose street is Covent Garden
     And whose name is Royal Opera House

  Scenario: Parsing an address where the street is in an old (1990) Ward
    When I parse the address 1A Egmont Road, Middlesbrough, TS4 2HT
    Then I get an address whose postcode is TS4 2HT
     And has no county
     And whose town is Middlesbrough
     And whose street is Egmont Road
     And whose number is 1A

  Scenario: Parsing an address with a number range
    When I parse the address 4-5 Bonhill Street, London, EC2A 4BX
    Then I get an address whose postcode is EC2A 4BX
     And whose city is London
     And whose street is Bonhill Street
     And whose number is 4-5

  Scenario: Parsing an address whose town ends in a city name
    When I parse the address Minusone Priory Road, Newbury, RG14 7QS
    Then I get an address whose postcode is RG14 7QS
     And whose town is Newbury
     And whose street is Priory Road
     And whose name is Minusone

  Scenario: Parsing an address with wrong city and road
    When I parse the address Idas Court, 4-6 Princes Road, Hull, HU5 2RD
    Then I get an address whose postcode is HU5 2RD
     And whose city is Hull
     And has no street
     And has no number
     And has no name
     And with the error ERR_NO_STREET
     And with the unmatched text Idas Court, 4-6 Princes Road

  Scenario: Parsing an address with a name and a number
    When I parse the address Idas Court, 4-6 Prince's Road, Kingston upon Hull, HU5 2RD
    Then I get an address whose postcode is HU5 2RD
     And whose city is Kingston upon Hull
     And whose street is Prince's Road
     And whose number is 4-6
     And whose name is Idas Court

  Scenario: Parsing an address with a flat number
    When I parse the address Flat 1.4, Ziggurat Building, 60-66 Saffron Hill, London, EC1N 8QX
    Then I get an address whose postcode is EC1N 8QX
     And whose city is London
     And whose street is Saffron Hill
     And whose number is 60-66
     And whose name is Ziggurat Building
     And whose flat is Flat 1.4

  Scenario: Parsing an address in Wales
    When I parse the address 50 Ammanford Road, Tycroes, Ammanford, SA18 3QJ
    Then I get an address whose postcode is SA18 3QJ
     And whose town is Ammanford
     And whose locality is Tycroes
     And whose street is Ammanford Road
     And whose number is 50

  Scenario: Parsing an address whose street ends with a locality name
    When I parse the address 3 Store, 311-318 High Holborn, London, WC1V 7BN
    Then I get an address whose postcode is WC1V 7BN
     And whose city is London
     And whose street is High Holborn
     And whose number is 311-318
     And whose name is 3 Store

  Scenario: Parsing an address on a business park or industrial estate
    When I parse the address 3 Bishops Square Business Park, Hatfield, AL10 9NA
    Then I get an address whose postcode is AL10 9NA
     And whose town is Hatfield
     And whose estate is Bishops Square Business Park
     And with the warning WARN_GUESSED_ESTATE
     And whose number is 3

  Scenario: Parsing an address with a dependent street
    When I parse the address 6 Elm Avenue, Runcorn Road, Birmingham, B12 8QX
    Then I get an address whose postcode is B12 8QX
     And has no county
     And whose city is Birmingham
     And whose street is Runcorn Road
     And whose dependent_street is Elm Avenue
     And with the warning WARN_GUESSED_DEPENDENT_STREET
     And whose number is 6

  Scenario: Parsing an address without a street
    When I parse the address Oakland, Fairseat, Sevenoaks TN15 7LT
    Then I get an address whose postcode is TN15 7LT
     And whose town is Sevenoaks
     And whose locality is Fairseat
     And whose name is Oakland

  Scenario: Parsing an address with more than one line before the name of the address
    When I parse the address Enfield Southgate, London Borough of Enfield, Civic Centre, Silver Street, ENFIELD, EN1 3ZW
    Then I get an address whose postcode is EN1 3ZW
     And has no county
     And whose town is ENFIELD
     And whose street is Silver Street
     And whose name is Civic Centre
     And whose second line is London Borough of Enfield
     And whose first line is Enfield Southgate

  Scenario: Parsing a long address with several lines before the street
    When I parse the address Department For Environment Food & Rural Affairs (D E F R A), State Veterinary Service, Animal Health Office, Hadrian House, Wavell Drive, Rosehill Industrial Estate, Carlisle, CA1 2TB
    Then I get an address whose postcode is CA1 2TB
     And whose city is Carlisle
     And whose estate is Rosehill Industrial Estate
     And with the warning WARN_GUESSED_ESTATE
     And whose street is Wavell Drive
     And whose name is Hadrian House
     And whose third line is Animal Health Office
     And whose second line is State Veterinary Service
     And whose first line is Department For Environment Food & Rural Affairs (D E F R A)

  Scenario: Parsing a long address with several lines and an industrial park
    When I parse the address GB Technical Services, Unit W7a, Warwick House, 18 Forge Lane, Minworth Industrial Park, Minworth, Sutton Coldfield, B76 1AH
    Then I get an address whose postcode is B76 1AH
     And whose town is Sutton Coldfield
     And whose locality is Minworth
     And whose estate is Minworth Industrial Park
     And whose street is Forge Lane
     And whose name is Warwick House
     And whose flat is Unit W7a
     And whose first line is GB Technical Services

  Scenario: Parsing an address where the name of the building contains commas
    When I parse the address Society of College, National & University Libraries, 102 Euston Street, London, NW1 2HA
    Then I get an address whose postcode is NW1 2HA
     And whose city is London
     And whose street is Euston Street
     And whose number is 102
     And whose name is Society of College, National & University Libraries

  Scenario: Parsing an address where the name contains lots of odd characters
    When I parse the address St. Judes & St. Pauls C of E (Va) Primary School, 10 Kingsbury Road, London, N1 4AZ
    Then I get an address whose postcode is N1 4AZ
     And whose city is London
     And whose street is Kingsbury Road
     And whose number is 10
     And whose name is St. Judes & St. Pauls C of E (Va) Primary School

  Scenario: Parsing an address with a curly apostrophe in it
    When I parse the address 1 Acre View, Bo’ness, EH51 9RQ
    Then I get an address whose postcode is EH51 9RQ
     And whose town is Bo'ness
     And whose street is Acre View
     And whose number is 1

  Scenario: Parsing an address where the first line contains commas
    When I parse the address Kirkland, Lane, Mathias & Perry, North Muskham Prebend Church Street, Southwell, NG25 0HQ
    Then I get an address whose postcode is NG25 0HQ
     And whose town is Southwell
     And whose street is Church Street
     And whose name is North Muskham Prebend
     And whose first line is Kirkland, Lane, Mathias & Perry

  Scenario: Parsing a British Forces address
    When I parse the address BFPO 281, BFPO, BF1 4FB
    Then I get an address whose postcode is BF1 4FB
     And whose name is BFPO
     And whose number is 281

  Scenario: Parsing an address near a road
    When I parse the address The National Museum of Computing, Bletchley Park, Sherwood Drive, Bletchley, Milton Keynes, MK3 6EB
    Then I get an address whose postcode is MK3 6EB
     And has no county
     And whose town is Milton Keynes
     And whose locality is Bletchley
     And whose street is Sherwood Drive
     And whose name is Bletchley Park
     And whose first line is The National Museum of Computing

  Scenario: Parsing an address whose postcode is invalid
    When I parse the address Open Data Institute, 3rd Floor, 65 Clifton Street, London EC2A 4JZ
    Then I get an address whose postcode is EC2A 4JZ
     And with the error ERR_BAD_POSTCODE
     And whose city is London
     And whose street is Clifton Street
     And whose number is 65
     And whose floor is 3rd Floor
     And whose first line is Open Data Institute

# Tests based on addresses from Redbridge

  Scenario: Parsing an address with no comma separating localities
    When I parse the address 8, Frank Slater House, Green Lane, Goodmayes Ilford, Essex IG3 9RS
    Then I get an address whose postcode is IG3 9RS
     And whose county is Essex
     And whose town is Ilford
     And whose locality is Goodmayes
     And whose street is Green Lane
     And whose name is Frank Slater House
     And whose flat is 8
     And with no errors
     And with no warnings

  Scenario: Parsing an flat in a numbered house
    When I parse the address Flat 1, 12, Coventry Road, Ilford, Essex IG1 4QR
    Then I get an address whose postcode is IG1 4QR
     And whose county is Essex
     And whose town is Ilford
     And whose street is Coventry Road
     And whose number is 12
     And whose flat is Flat 1

  Scenario: Parsing an address with an unrecognised street
    When I parse the address 576, New North Road, Hainault, Ilford, Essex IG6 3TG
    Then I get an address whose postcode is IG6 3TG
     And whose county is Essex
     And whose town is Ilford
     And whose locality is Hainault
     And whose street is New North Road
     And whose number is 576

  Scenario: Parsing an address with a missing postcode and no city
    When I parse the address Flat 2nd Floor, 96b, Cranbrook Road, Ilford, Essex IG1 4PN
    Then I get an address whose postcode is IG1 4PN
     And with the error ERR_BAD_POSTCODE
     And whose county is Essex
     And with the error ERR_BAD_COUNTY
     And whose town is Ilford
     And whose street is Cranbrook Road
     And whose number is 96b
     And whose floor is 2nd Floor
     And whose flat is Flat

  Scenario: Parsing an address with a missing street
    When I parse the address 279, New North Road, Hainault, Ilford, Essex IG6 3DX
    Then I get an address whose postcode is IG6 3DX
     And whose county is Essex
     And whose town is Ilford
     And whose locality is Hainault
     And whose street is New North Road
     And whose number is 279

  Scenario: Parsing an address where the locality name incorporates a town name
    When I parse the address Flat 2, 13, Chelmsford Road, South Woodford, London E18 2PW
    Then I get an address whose postcode is E18 2PW
     And whose city is London
     And whose locality is South Woodford
     And whose street is Chelmsford Road
     And whose number is 13
     And whose flat is Flat 2

  Scenario: Parsing an address where the locality name is the same as a street name
    When I parse the address 1, Dale Court, Grove Hill, London E18 2JD
    Then I get an address whose postcode is E18 2JD
     And whose city is London
     And whose street is Grove Hill
     And whose dependent_street is Dale Court
     And whose number is 1

  Scenario: Parsing an address where there's a flat number in a named property
    When I parse the address 4 Hope House, 12, Village Way, Barkingside Ilford, Essex IG6 1RP
    Then I get an address whose postcode is IG6 1RP
     And whose county is Essex
     And whose town is Ilford
     And whose locality is Barkingside
     And whose street is Village Way
     And whose number is 12
     And whose name is Hope House
     And whose flat is 4