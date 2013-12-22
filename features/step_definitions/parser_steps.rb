require 'rspec'
require File.expand_path('../../../lib/parse', __FILE__)

When(/^I parse the address (.+)$/) do |address|
	@address = AddressParser::Address.parse(address)
end

Then(/whose (inferred )?([^ ]+)( ([^ ]+))? (is|includes) (the (float))?(.+)$/) do |inferred, property, m3, subproperty, comparison, m5, type, value|
	test = @address
	test = test[:inferred] if inferred
	if subproperty == 'line' && ['first', 'second', 'third'].include?(property)
		index = 0 if property == 'first'
		index = 1 if property == 'second'
		index = 2 if property == 'third'
		test = test[:lines][index]
	else
		test = test[property.to_sym]
		test = test[subproperty.to_sym] if subproperty
	end
	value = value.to_f if type == 'float'
	if comparison == 'includes'
		test.should include value
	else
		test.should == value
	end
end

Then(/has no (inferred )?([^ ]+)$/) do |inferred, property|
	test = @address
	test = test[:inferred] if inferred
	test = test[property.to_sym]
	test.should == nil
end

Then(/with the error ([^ ]+)$/) do |code|
	@address[:errors].should include code
end

Then(/with no ([^ ]+)$/) do |property|
	@address[property.to_sym].length.should == 0
end

Then(/with the warning ([^ ]+)$/) do |code|
	@address[:warnings].should include code
end

Then(/with the unmatched text (.+)$/) do |text|
	@address[:unmatched].should == text
end
