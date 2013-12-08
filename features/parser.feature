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
		 And whose line1 is Open Data Institute
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
  	 And with the error ERR_NOAREA
  	 And with the error ERR_NOSTREET
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

  Scenario: Parsing an address with a dependent street
  	When I parse the address 6 Elm Avenue, Runcorn Road, Birmingham, B12 8QX
  	Then I get an address whose postcode is B12 8QX
  	 And whose county is Birmingham
  	 And whose street is Runcorn Road
  	 And whose dependent_street is Elm Avenue
  	 And whose number is 6

	# Scenario: An address in a county which is a substring of another county
	# 	South Gloucestershire ends with Gloucestershire
	# 	North East Lincolnshire ends with Lincolnshire
	# 	North Lincolnshire ends with Lincolnshire
	# 	East Renfrewshire ends with Renfrewshire
	# 	Bath and North East Somerset ends with Somerset
	# 	North Somerset ends with Somerset