require 'rspec'
require File.expand_path('../../../lib/parse', __FILE__)

When(/^I parse the address (.+) with the postcode (.+)$/) do |address,postcode|
	@address = AddressParser::Address.parse(address, postcode: postcode)
end

When(/^I parse the address (.+)$/) do |address|
	@address = AddressParser::Address.parse(address)
end

Then(/whose (.+) is (.+)$/) do |property, value|
  @address[property.to_sym].should == value
end
