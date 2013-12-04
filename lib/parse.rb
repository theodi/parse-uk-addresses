require 'couchrest'
require 'yaml'
require 'Dotenv'

Dotenv.load

module AddressParser

	class Address

		@@codepoint_db = CouchRest.database!(ENV['CODEPOINT_DB'])
		@@features_db = CouchRest.database!(ENV['FEATURES_DB'])
		@@roads_db = CouchRest.database!(ENV['ROADS_DB'])
		@@ons_db = CouchRest.database!(ENV['ONS_DB'])

		def self.parse(address, postcode: nil)
			parsed = {
				:address => address,
				:remainder => address,
				:postcode => postcode,
				:city => "London",
				:street => "Clifton Street",
				:number => "65",
				:errors => [],
				:inferred => {}
			}
			populate_postcode(parsed)
			puts parsed.to_yaml
			return parsed
		end

		private

		def self.populate_postcode(parsed)
			unless parsed[:postcode]
				m = /^(.+)(,?\s+)([A-Z][A-Z]?[0-9]([A-Z]|[0-9])? [0-9][A-Z][A-Z])$/.match(parsed[:address])
				if m
					parsed[:remainder] = m[1]
					parsed[:postcode] = m[3]
				end
			end
			codepoint = @@codepoint_db.get(parsed[:postcode])
			parsed[:inferred][:lat] = codepoint['Location']['latitude']
			parsed[:inferred][:long] = codepoint['Location']['longitude']
			parsed[:inferred][:county] = hash(@@ons_db.get(codepoint['Admin_county_code'])) unless codepoint['Admin_county_code'] == ''
			parsed[:inferred][:district] = hash(@@ons_db.get(codepoint['Admin_district_code']))
			parsed[:inferred][:ward] = hash(@@ons_db.get(codepoint['Admin_ward_code']))
			parsed[:inferred][:regional_health_authority] = hash(@@ons_db.get(codepoint['NHS_regional_HA_code'])) unless codepoint['NHS_regional_HA_code'] == ''
			parsed[:inferred][:health_authority] = hash(@@ons_db.get(codepoint['NHS_HA_code'])) unless codepoint['NHS_HA_code'] == ''
			return parsed
		end

		def self.hash(doc)
			hash = {}
			doc.each do |key,value|
				hash[key.to_sym] = value unless key == '_rev'
			end
			return hash
		end

	end

end
