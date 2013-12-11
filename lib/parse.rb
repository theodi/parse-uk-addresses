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
		@@cities = {}
		@@features_db.view('cities/all', { :include_docs => true })['rows'].each do |r|
			r['key'].split(/\s*\/\s*/).each do |name|
				@@cities[name] = r['doc']
				@@cities['Hull'] = r['doc'] if name == 'Kingston upon Hull'
				@@cities['Newcastle'] = r['doc'] if name == 'Newcastle upon Tyne'
			end
		end

		def self.parse(address)
			address.gsub!(/’/,"'")
			parsed = {
				:address => address,
				:remainder => address,
				:errors => [],
				:warnings => [],
				:inferred => {}
			}
			populate_postcode(parsed)
			unless parsed[:postcode] =~ /^BF/
				populate_from_list(parsed, :county, @@counties)
				populate_from_list(parsed, :city, @@cities.keys)
				populate_from_area(parsed)
				populate_estate(parsed)
				populate_road(parsed)
				if parsed[:street]
					populate_dependent_street(parsed)
					populate_number(parsed)
				else
					parsed[:errors].push('ERR_NO_STREET')
				end
				if parsed[:street] || parsed[:locality] || parsed[:town]
					populate_estate(parsed)
					populate_name(parsed)
					populate_floor(parsed)
					populate_flat(parsed)
					populate_lines(parsed)
				else
					parsed[:unmatched] = parsed[:remainder] if parsed[:remainder] != ''
				end
				unless parsed[:city] || parsed[:town] || parsed[:locality]
					parsed[:errors].push('ERR_NO_AREA')
				end
			end
			parsed[:remainder] = ''
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
					parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
				end
			end
			if parsed[:postcode] =~ /^BF/
				parsed[:name] = 'BFPO'
				m = /BFPO ([0-9]+)/.match(parsed[:address])
				parsed[:number] = m[1] if m
			else
				begin
					codepoint = @@codepoint_db.get(parsed[:postcode])
					parsed[:inferred][:lat] = codepoint['Location']['latitude']
					parsed[:inferred][:long] = codepoint['Location']['longitude']
					parsed[:inferred][:pqi] = codepoint['Positional_quality_indicator'].to_i
					parsed[:inferred][:county] = hash(@@ons_db.get(codepoint['Admin_county_code'])) unless codepoint['Admin_county_code'] == ''
					parsed[:inferred][:district] = hash(@@ons_db.get(codepoint['Admin_district_code']))
					parsed[:inferred][:ward] = hash(@@ons_db.get(codepoint['Admin_ward_code']))
					parsed[:inferred][:regional_health_authority] = hash(@@ons_db.get(codepoint['NHS_regional_HA_code'])) unless codepoint['NHS_regional_HA_code'] == ''
					parsed[:inferred][:health_authority] = hash(@@ons_db.get(codepoint['NHS_HA_code'])) unless codepoint['NHS_HA_code'] == ''
				rescue RestClient::ResourceNotFound
					# no such postcode
					parsed[:errors].push('ERR_BAD_POSTCODE')
				end
			end
			return parsed
		end

		def self.populate_from_list(parsed, property, list)
			# unless [:city,:county].include?(property)
			# 	puts property.to_s
			# 	puts list
			# end
			if parsed[:county] && 
				 [:city,:town].include?(property) && 
				 list.map { |i| i.upcase }.include?(parsed[:county].upcase)
				parsed[property] = parsed[:county]
				parsed.delete(:county)
			else
				list.sort_by{|i| i.length}.reverse.each do |item|
					m = Regexp.new("(.+#{property == :street ? '\s+' : ',\s*'})(#{item})(,\s*.+)?$", Regexp::IGNORECASE).match(parsed[:remainder])
					if m
						parsed[:remainder] = m[1]
						parsed[:remainder].gsub!(/(,\s*|\s+)$/, '')
						parsed[property] = m[2]
						if property == :city && !parsed[:inferred][:lat]
							city = @@cities[item]
							parsed[:inferred][:lat] = city['Location']['latitude']
							parsed[:inferred][:long] = city['Location']['longitude']
							parsed[:inferred][:county] = { :full_name => city['FULL_COUNTY'] }
						end
						if m[3]
							parsed[:unmatched] = m[3].gsub!(/^(,\s*|\s+)/, '')
							parsed[:warnings].push('WARN_UNKNOWN_AREA')
						end
						break
					end
				end
			end
			return parsed
		end

		def self.populate_from_area(parsed)
			location = [parsed[:inferred][:lat], parsed[:inferred][:long]]
			latfuzz = parsed[:inferred][:pqi] ? parsed[:inferred][:pqi].to_f / 60 : 0.2
			longfuzz = parsed[:inferred][:pqi] ? parsed[:inferred][:pqi].to_f / 60 : 0.4
			startkey = [location[0] - latfuzz, location[1] - latfuzz]
			endkey = [location[0] + longfuzz, location[1] + longfuzz]
			inlat = @@features_db.view('localities_by_location/all', {:startkey => startkey, :endkey => endkey})
			inlatlong = []
			inlat['rows'].each do |f|
				inlatlong.push(f['id']) if f['key'][1] >= startkey[1] && f['key'][1] < endkey[1]
			end
			towns = {}
			localities = {}
			@@features_db.get_bulk(inlatlong)['rows'].each do |feature|
				if feature['doc']['F_CODE'] == 'T'
					feature['doc']['DEF_NAM'].split('/').each do |t|
						towns[t] = feature['doc']
					end
				else
					feature['doc']['DEF_NAM'].split('/').each do |t|
						localities[t] = feature['doc']
					end
				end
			end
			populate_from_list(parsed, :town, towns.keys)
			populate_from_list(parsed, :locality, localities.keys)
		end

		def self.populate_estate(parsed)
			m = /^(.+,\s+)?((([A-Z]?[0-9][-\.0-9a-zA-Z]*)\s+)?([^,]+\s(Business Park|Industrial Estate|Industrial Park)))$/.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:number] = m[4] if m[4]
				parsed[:estate] = m[5]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
				parsed[:warnings].push('WARN_GUESSED_ESTATE')
			end
			return parsed
		end

		def self.populate_road(parsed)
			location = [parsed[:inferred][:lat], parsed[:inferred][:long]]
			latfuzz = parsed[:inferred][:pqi] ? parsed[:inferred][:pqi].to_f / 4000 : 0.2
			longfuzz = parsed[:inferred][:pqi] ? parsed[:inferred][:pqi].to_f / 2000 : 0.4
			startkey = ['', location[0] - latfuzz, location[1] - latfuzz]
			endkey = ['', location[0] + longfuzz, location[1] + longfuzz]
			if parsed[:inferred][:ward]
				startkey[0] = parsed[:inferred][:ward][:name]
				endkey[0] = parsed[:inferred][:ward][:name]
				roads = get_roads('roads_by_location_in_locality/all', startkey, endkey)
				populate_from_list(parsed, :street, roads.keys)
				unless parsed[:street]
					district = parsed[:inferred][:district][:full_name]
					district = district.gsub(' - ', ' / ')
					startkey[0] = district
					endkey[0] = district
					roads = get_roads('roads_by_location_in_district/all', startkey, endkey)
					populate_from_list(parsed, :street, roads.keys)
				end
			end
			if !parsed[:street] && (parsed[:inferred][:county] || parsed[:county])
				county = parsed[:inferred][:county] ? parsed[:inferred][:county][:full_name] : parsed[:county]
				county = county.gsub(' - ', ' / ')
				startkey[0] = county
				endkey[0] = county
				roads = get_roads('roads_by_location_in_county/all', startkey, endkey)
				populate_from_list(parsed, :street, roads.keys)
			end
			unless parsed[:street]
				startkey[0] = nil
				endkey[0] = nil
				roads = get_roads('roads_by_location/all', startkey, endkey)
				populate_from_list(parsed, :street, roads.keys)
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
				roads[road['doc']['Name']] = road['doc'] if road['doc']['Name']
			end
			return roads
		end

		def self.populate_dependent_street(parsed)
			m = /^([^ ]+,?\s+)([^ ,]+(\s[^ ,]+)*\s(Road|Street|Hill|Avenue|Mews|Park|Parade|Square|Court))$/.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:dependent_street] = m[2]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
				parsed[:warnings].push('WARN_GUESSED_DEPENDENT_STREET')
			end
			return parsed
		end

		def self.populate_number(parsed)
			m = /^(.+(\s|,))?([0-9]+[a-zA-Z]*(-[0-9]+[a-zA-Z]*)?)$/.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:number] = m[3]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
			end
			return parsed
		end

		def self.populate_name(parsed)
			m = /^(.+,\s*)?([^,]+)$/.match(parsed[:remainder])
			if m && !(/\b(floor|flat|unit)\b/i =~ m[2])
				if m[2] =~ /\s(&|and)\s/
					parsed[:name] = parsed[:remainder]
					parsed[:remainder] = ''
				else
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

		def self.populate_flat(parsed)
			m = /^(.+(\s|,))?((Flat|Unit) [^,]*)$/i.match(parsed[:remainder])
			if m
				parsed[:remainder] = m[1] || ''
				parsed[:flat] = m[3]
				parsed[:remainder].gsub!(/(,\s*|,?\s+)$/, '')
			end
			return parsed
		end

		def self.populate_lines(parsed)
			m = /^(.+\s(&|and)\s[^,]+)(.*)$/.match(parsed[:remainder])
			if m
				parsed[:lines] = [] unless parsed[:lines]
				parsed[:lines].push(m[1])
				parsed[:remainder] = m[3].gsub(/^,\s*/, '') || ''
				populate_lines(parsed) unless parsed[:remainder] == ''
			elsif parsed[:remainder] != ''
				parsed[:lines] = [] unless parsed[:lines]
				parsed[:remainder].split(',').each do |l|
					parsed[:lines].push(l.gsub(/(^\s+)|(\s+$)/, ''))
				end
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
