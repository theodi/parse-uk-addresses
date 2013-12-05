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

  Scenario: Parsing an address without a number
    When I parse the address Royal Opera House, Covent Garden, London, WC2E 9DD
    Then I get an address whose postcode is WC2E 9DD
     And whose city is London
     And whose street is Covent Garden
     And whose line1 is Royal Opera House

	# Scenario: An address in a county which is a substring of another county
	# 	South Gloucestershire ends with Gloucestershire
	# 	North East Lincolnshire ends with Lincolnshire
	# 	North Lincolnshire ends with Lincolnshire
	# 	East Renfrewshire ends with Renfrewshire
	# 	Bath and North East Somerset ends with Somerset
	# 	North Somerset ends with Somerset