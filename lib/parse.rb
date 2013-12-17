require 'couchrest'
require 'yaml'
require 'Dotenv'

Dotenv.load

module AddressParser

	class Address

		@@debug = false

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
			address.gsub!(/\u2019/,"'")
			parsed = {
				:address => address,
				:remainder => address,
				:errors => [],
				:warnings => [],
				:inferred => {}
			}
			populate_postcode(parsed)
			unless parsed[:postcode] =~ /^BF/
				if parsed[:inferred][:lat]
					populate_road(parsed)
					if parsed[:street]
						populate_dependent_street(parsed)
						populate_number(parsed)
					else
						parsed[:errors].push('ERR_NO_STREET')
					end
					populate_from_list(parsed, :county, @@counties)
					populate_from_list(parsed, :city, @@cities.keys)
					populate_from_area(parsed)
					populate_estate(parsed, :unmatched)
				else
					populate_from_list(parsed, :county, @@counties)
					populate_from_list(parsed, :city, @@cities.keys)
					populate_from_area(parsed)
					populate_estate(parsed, :unmatched)
					populate_road(parsed)
					if parsed[:street]
						populate_dependent_street(parsed)
						populate_number(parsed)
					else
						parsed[:errors].push('ERR_NO_STREET')
					end
				end
				if parsed[:street] || parsed[:locality] || parsed[:town]
					populate_estate(parsed, :remainder)
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
			puts parsed.to_yaml if @@debug
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
					parsed[:inferred][:latlong_source] = :postcode
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
			unless !@@debug || [:city,:county].include?(property)
				puts "#{property.to_s} in #{parsed[parsed[:street] ? :unmatched : :remainder]}"
				puts list
			end
			if parsed[:county] && 
				 [:city,:town].include?(property) && 
				 list.map { |i| i.upcase }.include?(parsed[:county].upcase)
				parsed[property] = parsed[:county]
				parsed.delete(:county)
			else
				items = list.sort_by{|i| i.length}.reverse!.join('|')
				m = Regexp.new("^(.+(\s+|,\s*))??(#{items})(,\s*.+)?$", Regexp::IGNORECASE).match(parsed[parsed[:street] ? :unmatched : :remainder])
				if m
					parsed[parsed[:street] ? :unmatched : :remainder] = m[1] ? m[1].gsub!(/(,\s*|\s+)$/, '') : ''
					parsed[property] = m[3]
					unless parsed[:inferred][:lat]
						if property == :city
							city = @@cities[parsed[:city]]
							parsed[:inferred][:lat] = city['Location']['latitude']
							parsed[:inferred][:long] = city['Location']['longitude']
							parsed[:inferred][:latlong_source] = :city
							parsed[:inferred][:county] = { :full_name => city['FULL_COUNTY'] }
						end
					end
					if m[4]
						parsed[:unmatched] = m[4].gsub!(/^(,\s*|\s+)/, '')
						unless parsed[:street]
							parsed[:warnings].push('WARN_UNKNOWN_AREA')
						end
					end
				end
			end
			return parsed
		end

		def self.populate_areas(parsed, features)
			towns = {}
			localities = {}
			features.each do |feature|
				if feature['doc']['F_CODE'] == 'T'
					feature['doc']['DEF_NAM'].split('/').each do |t|
						towns[t] = feature['doc']
					end
				elsif feature['doc']['F_CODE'] == 'O'
					feature['doc']['DEF_NAM'].split('/').each do |t|
						localities[t] = feature['doc']
					end
				end
			end
			populate_from_list(parsed, :town, towns.keys)
			populate_from_list(parsed, :locality, localities.keys)
			unless parsed[:inferred][:lat]
				if parsed[:locality]
					locality = localities[parsed[:locality]]
					parsed[:inferred][:lat] = locality['Location']['latitude']
					parsed[:inferred][:long] = locality['Location']['longitude']
					parsed[:inferred][:latlong_source] = :locality
				elsif parsed[:town]
					town = towns[parsed[:town]]
					parsed[:inferred][:lat] = town['Location']['latitude']
					parsed[:inferred][:long] = town['Location']['longitude']
					parsed[:inferred][:latlong_source] = :town
				end						
			end
		end

		def self.populate_from_area(parsed)
			if parsed[:inferred][:lat]
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
				features = @@features_db.get_bulk(inlatlong)['rows']
			elsif parsed[:county]
				features = @@features_db.view('localities_by_county/all', {:key => parsed[:county], :include_docs => true})['rows']
			end
			if features
				populate_areas(parsed, features)
				unless parsed[:locality] || parsed[:town]
					parsed[:errors].push('ERR_BAD_COUNTY')
					features = @@features_db.view('features_by_name/all', {:keys => parsed[:remainder].split(/\s*,\s*/), :include_docs => true})['rows']
					populate_areas(parsed, features)
				end
			end
		end

		def self.populate_estate(parsed, property)
			m = /^(.+,\s+)?((([A-Z]?[0-9][-\.0-9a-zA-Z]*)\s+)?([^,]+\s(Business Park|Industrial Estate|Industrial Park)))$/.match(parsed[property])
			if m
				parsed[property] = m[1] ? m[1].gsub!(/(,\s*|,?\s+)$/, '') : ''
				parsed[:number] = m[4] if m[4]
				parsed[:estate] = m[5]
				parsed[:warnings].push('WARN_GUESSED_ESTATE')
			end
			return parsed
		end

		def self.populate_road(parsed)
			if parsed[:inferred][:latlong_source] == :postcode
				minLat = (parsed[:inferred][:lat] / ENV['PIN_LAT'].to_f).floor
				maxLat = (parsed[:inferred][:lat] / ENV['PIN_LAT'].to_f).ceil
				minLong = (parsed[:inferred][:long] / ENV['PIN_LONG'].to_f).floor
				maxLong = (parsed[:inferred][:long] / ENV['PIN_LONG'].to_f).ceil
				keys = [
					[nil,minLat,minLong],
					[nil,minLat,maxLong],
					[nil,maxLat,minLong],
					[nil,maxLat,maxLong]
				]
				roads = {}
				@@roads_db.view('roads_by_location/all', { :keys => keys, :include_docs => true })['rows'].each do |road|
					roads[road['doc']['Name']] = road['doc'] if road['doc']['Name']
				end
				populate_from_list(parsed, :street, roads.keys)
			else
				road = /([0-9]+[^ ]*)? ([^,]+)$/.match(parsed[:remainder])[2]
				roads = @@roads_db.view('roads_by_name/all', {:key => road.upcase, :include_docs => true})['rows']
				if roads.empty?
					road = /([^ ]+) (.+)$/.match(road)[2]
					roads = @@roads_db.view('roads_by_name/all', {:key => road.upcase, :include_docs => true})['rows']
				end
				roads.sort_by! { |row|
					x = row['doc']['Centre']['latitude'] - parsed[:inferred][:lat]
					y = row['doc']['Centre']['longitude'] = parsed[:inferred][:long]
					x * x + y * y
				}
				unless roads.empty?
					populate_from_list(parsed, :street, [roads[0]['doc']['Name']])
					parsed[:inferred][:lat] = roads[0]['doc']['Centre']['latitude']
					parsed[:inferred][:long] = roads[0]['doc']['Centre']['longitude']
					parsed[:inferred][:latlong_source] = :street
				end
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
			m = /^(.+(\s|,))??((Flat|Unit)( [^,]+)?|[-0-9\.]+)$/i.match(parsed[:remainder])
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
