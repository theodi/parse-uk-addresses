require 'rspec'
require File.expand_path('../../../lib/parse', __FILE__)

When(/^I parse the address (.+)$/) do |address|
	@address = AddressParser::Address.parse(address)
end

Then(/whose (inferred )?([^ ]+)( ([^ ]+))? is (the (float))?(.+)$/) do |inferred, property, m3, subproperty, m5, type, value|
	test = @address
	test = test[:inferred] if inferred
	test = test[property.to_sym]
	test = test[subproperty.to_sym] if subproperty
	value = value.to_f if type == 'float'
	test.should == value
end

Then(/has no ([^ ]+)$/) do |property|
	@address[property.to_sym].should == nil
end

Then(/with the error ([^ ]+)$/) do |code|
	@address[:errors].include?(code)
end

Then(/with the unmatched text (.+)$/) do |text|
	@address[:unmatched] = text
end
