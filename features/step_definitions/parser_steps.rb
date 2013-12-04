require 'rspec'
require File.expand_path('../../../lib/parse', __FILE__)

When(/^I parse the address (.+)( with the postcode (.+))?$/) do |address,m2,postcode|
	@address = AddressParser::Address.parse(address, postcode: postcode)
end

Then(/whose (inferred )?([^ ]+)( ([^ ]+))? is (the (float))?(.+)$/) do |inferred, property, m3, subproperty, m5, type, value|
	test = @address
	test = test[:inferred] if inferred
	test = test[property.to_sym]
	test = test[subproperty.to_sym] if subproperty
	value = value.to_f if type == 'float'
	test.should == value
end
