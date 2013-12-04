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
		 And whose inferred lat is the float 51.52238743450444
  	 And whose inferred long is the float -0.08364849577490492
  	 And whose inferred district name is Hackney
  	 And whose inferred ward name is Haggerston
  	 And whose inferred regional_health_authority name is London Programme for IT (LPFiT)
  	 And whose inferred health_authority name is London

	Scenario: Parsing another address with a separate postcode
		When I parse the address 92, Liston Way, Woodford Green, Essex with the postcode IG8 7BL
		Then I get an address whose postcode is IG8 7BL
		 # And whose county is Essex
		 # And whose locality is Woodford Green
		 # And whose street is Liston Way
		 # And whose number is 92