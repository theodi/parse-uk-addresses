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

		@@counties = @@features_db.view('counties/all', { :group => true })['rows'].map { |r| r['key'] }
		@@cities = @@features_db.view('cities/all')['rows'].map { |r| r['key'] }

		def self.parse(address, postcode: nil)
			parsed = {
				:address => address,
				:remainder => address,
				:postcode => postcode,
				:street => "Clifton Street",
				:number => "65",
				:errors => [],
				:inferred => {}
			}
			populate_postcode(parsed)
			populate_from_list(parsed, :county, @@counties)
			populate_from_list(parsed, :city, @@cities)
			populate_from_area(parsed)
			# puts parsed.to_yaml
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
			parsed[:inferred][:pqi] = codepoint['Positional_quality_indicator'].to_i
			parsed[:inferred][:county] = hash(@@ons_db.get(codepoint['Admin_county_code'])) unless codepoint['Admin_county_code'] == ''
			parsed[:inferred][:district] = hash(@@ons_db.get(codepoint['Admin_district_code']))
			parsed[:inferred][:ward] = hash(@@ons_db.get(codepoint['Admin_ward_code']))
			parsed[:inferred][:regional_health_authority] = hash(@@ons_db.get(codepoint['NHS_regional_HA_code'])) unless codepoint['NHS_regional_HA_code'] == ''
			parsed[:inferred][:health_authority] = hash(@@ons_db.get(codepoint['NHS_HA_code'])) unless codepoint['NHS_HA_code'] == ''
			return parsed
		end

		def self.populate_from_list(parsed, property, list)
			selected = nil
			list.each do |item|
				selected = item if parsed[:remainder].end_with?(item)
			end
			if selected
				parsed[:remainder] = parsed[:remainder].slice(0, parsed[:remainder].length - selected.length)
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
				parsed[property] = selected
			end
			return parsed
		end

		def self.populate_from_area(parsed)
			location = [parsed[:inferred][:lat], parsed[:inferred][:long]]
			fuzz = parsed[:inferred][:pqi].to_f / 500
			startkey = [location[0] - fuzz, location[1] - fuzz]
			endkey = [location[0] + fuzz, location[1] + fuzz]
			inlat = @@features_db.view('localities_by_location/all', {:startkey => startkey, :endkey => endkey})
			inlatlong = []
			inlat['rows'].each do |f|
				inlatlong.push(f['id']) if f['key'][1] >= startkey[1] && f['key'][1] < endkey[1]
			end
			towns = []
			localities = []
			@@features_db.get_bulk(inlatlong)['rows'].each do |feature|
				if feature['doc']['F_CODE'] == 'T'
					towns.push(feature['doc']['DEF_NAM'])
				else
					localities.push(feature['doc']['DEF_NAM'])
				end
			end
			populate_from_list(parsed, :town, towns)
			populate_from_list(parsed, :locality, localities)
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
