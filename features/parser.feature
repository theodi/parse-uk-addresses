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
  	 And whose county is Middlesbrough
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
  	 And has no city
  	 And has no street
  	 And has no number
  	 And has no name
  	 And with the error ERR_NO_AREA
  	 And with the error ERR_NO_STREET
  	 And with the unmatched text Idas Court, 4-6 Princes Road, Hull

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
  	 And whose county is Birmingham
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
  	 And whose county is ENFIELD
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

  Scenario: Parsing an address whose postcode isn't in CodePoint Open
  	When I parse the address St. Judes & St. Pauls C of E (Va) Primary School, 10 Kingsbury Road, London, N1 4AZ
  	Then I get an address whose postcode is N1 4AZ
  	 And whose city is London
  	 And whose street is Kingsbury Road
  	 And whose number is 10
  	 And whose name is St. Judes & St. Pauls C of E (Va) Primary School

  	 # TODO: city Hull
  	 # TODO: city Birmingham

	# Scenario: An address in a county which is a substring of another county
	# 	South Gloucestershire ends with Gloucestershire
	# 	North East Lincolnshire ends with Lincolnshire
	# 	North Lincolnshire ends with Lincolnshire
	# 	East Renfrewshire ends with Renfrewshire
	# 	Bath and North East Somerset ends with Somerset
	# 	North Somerset ends with Somerset