require 'couchrest'
require 'yaml'

CONFIG = YAML.load_file(File.expand_path('../../config/config.yml', __FILE__))

module AddressParser

	class Address

		@@codepoint_db = CouchRest.database!(CONFIG['codepoint_db'])
		@@features_db = CouchRest.database!(CONFIG['features_db'])
		@@roads_db = CouchRest.database!(CONFIG['roads_db'])
		@@ons_db = CouchRest.database!(CONFIG['ons_db'])

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
			# codepoint = @@codepoint_db.get(parsed[:postcode])
			# parsed[:inferred][:lat] = codepoint['Location']['latitude']
			# parsed[:inferred][:long] = codepoint['Location']['longitude']
			# parsed[:inferred][:county] = @@ons_db.get(codepoint['Admin_county_code']).to_hash unless codepoint['Admin_county_code'] == ''
			# parsed[:inferred][:district] = @@ons_db.get(codepoint['Admin_district_code']).to_hash
			# parsed[:inferred][:ward] = @@ons_db.get(codepoint['Admin_ward_code']).to_hash
			# parsed[:inferred][:regional_health_authority] = @@ons_db.get(codepoint['NHS_regional_HA_code']).to_hash unless codepoint['NHS_regional_HA_code'] == ''
			# parsed[:inferred][:health_authority] = @@ons_db.get(codepoint['NHS_HA_code']).to_hash unless codepoint['NHS_HA_code'] == ''
			return parsed
		end

	end

end
