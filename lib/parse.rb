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

		def self.parse(address)
			parsed = {
				:address => address,
				:remainder => address,
				:errors => [],
				:inferred => {}
			}
			populate_postcode(parsed)
			populate_from_list(parsed, :county, @@counties)
			populate_from_list(parsed, :city, @@cities)
			populate_from_area(parsed)
			populate_road(parsed)
			populate_name_or_number(parsed)
			populate_floor(parsed)
			parsed[:line1] = parsed[:remainder] if parsed[:remainder] != ''
			return parsed
		end

		private

		def self.populate_postcode(parsed)
			unless parsed[:postcode]
				m = /^(.+)(,?\s+)([A-Z][A-Z]?[0-9]([A-Z]|[0-9])? [0-9][A-Z][A-Z])$/.match(parsed[:address])
				if m
					parsed[:remainder] = m[1]
					parsed[:postcode] = m[3]
					parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
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
				selected = item if Regexp.new("\\b#{item}$", Regexp::IGNORECASE) =~ parsed[:remainder]
			end
			if selected
				parsed[property] = parsed[:remainder].slice(-selected.length, selected.length)
				parsed[:remainder] = parsed[:remainder].slice(0, parsed[:remainder].length - selected.length)
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
			end
			return parsed
		end

		def self.populate_from_area(parsed)
			location = [parsed[:inferred][:lat], parsed[:inferred][:long]]
			fuzz = parsed[:inferred][:pqi].to_f / 300
			startkey = [location[0] - fuzz, location[1] - fuzz]
			endkey = [location[0] + fuzz, location[1] + fuzz]
			inlat = @@features_db.view('localities_by_location/all', {:startkey => startkey, :endkey => endkey})
			inlatlong = []
			inlat['rows'].each do |f|
				inlatlong.push(f['id']) if f['key'][1] >= startkey[1] && f['key'][1] < endkey[1]
			end
			towns = {}
			localities = {}
			@@features_db.get_bulk(inlatlong)['rows'].each do |feature|
				if feature['doc']['F_CODE'] == 'T'
					towns[feature['doc']['DEF_NAM']] = feature['doc']
				else
					localities[feature['doc']['DEF_NAM']] = feature['doc']
				end
			end
			populate_from_list(parsed, :town, towns.keys)
			populate_from_list(parsed, :locality, localities.keys)
		end

		def self.populate_road(parsed)
			location = [parsed[:inferred][:lat], parsed[:inferred][:long]]
			fuzz = parsed[:inferred][:pqi].to_f / 3000
			startkey = [parsed[:inferred][:ward][:name], location[0] - fuzz, location[1] - fuzz]
			endkey = [parsed[:inferred][:ward][:name], location[0] + fuzz, location[1] + fuzz]
			roads = get_roads('roads_by_location/all', startkey, endkey)
			populate_from_list(parsed, :street, roads.keys)
			unless parsed[:street]
				district = parsed[:inferred][:district][:full_name]
				startkey[0] = district
				endkey[0] = district
				roads = get_roads('roads_by_location_in_district/all', startkey, endkey)
				populate_from_list(parsed, :street, roads.keys)
				if !parsed[:street] && (parsed[:inferred][:county] || parsed[:county])
					county = parsed[:inferred][:county] ? parsed[:inferred][:county][:full_name] : parsed[:county]
					startkey[0] = county
					endkey[0] = county
					roads = get_roads('roads_by_location_in_county/all', startkey, endkey)
					populate_from_list(parsed, :street, roads.keys)
				end
			end
			if parsed[:street]
				road = roads[parsed[:street].upcase]
				parsed[:inferred][:tile_10k] = road['Tile_10k']
				parsed[:inferred][:tile_25k] = road['Tile_25k']
			end
			return parsed
		end

		def self.get_roads(view, startkey, endkey)
			inlat = @@roads_db.view(view, {:startkey => startkey, :endkey => endkey})
			inlatlong = []
			inlat['rows'].each do |f|
				inlatlong.push(f['id']) if f['key'][2] >= startkey[2] && f['key'][2] < endkey[2]
			end
			roads = {}
			@@roads_db.get_bulk(inlatlong)['rows'].each do |road|
				roads[road['doc']['Name']] = road['doc']
			end
			return roads
		end

		def self.populate_name_or_number(parsed)
			m = /^(.+(\s|,))?([0-9]+[a-zA-Z]*(-[0-9]+[a-zA-Z]*)?)$/.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:number] = m[3]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
			else
				m = /^(.+,\s*)?([^,]+)$/.match(parsed[:remainder])
				if m
					parsed[:remainder] = m[1] || ''
					parsed[:name] = m[2]
					parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
				end
			end
			return parsed
		end

		def self.populate_floor(parsed)
			m = /^(.+(\s|,))?([0-9]+[a-zA-Z]* Floor|Floor [0-9]+[a-zA-Z]*)$/i.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:floor] = m[3]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
			end
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
