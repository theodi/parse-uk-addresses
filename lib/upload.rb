require 'csv'
require 'yaml'
require 'dotenv'
require 'couchrest'
require 'breasal'

Dotenv.load

module Upload

	class Designs

		def self.load

			ons_db = CouchRest.database!(ENV['ONS_DB'])
			features_db = CouchRest.database!(ENV['FEATURES_DB'])
			roads_db = CouchRest.database!(ENV['ROADS_DB'])
			codepoint_db = CouchRest.database!(ENV['CODEPOINT_DB'])

			ons_db.bulk_save([{
				"_id" => "_design/area",
				:views => {
					:types => {
						:map => "function(doc){emit(doc.type,doc.name)}"
					}
				}
			}])

			features_db.bulk_save([{
				"_id" => "_design/counties",
				:views => {
					:all => {
						:map => "function(doc){emit(doc.FULL_COUNTY,1)}",
						:reduce => "_sum"
					}
				}
			}, {
				"_id" => "_design/cities",
				:views => {
					:all => {
						:map => "function(doc){if(doc.F_CODE==='C'){emit(doc.DEF_NAM,doc.FULL_COUNTY)}}"
					}
				}
			}, {
				"_id" => "_design/localities_by_location",
				:views => {
					:all => {
						:map => "function(doc){if(doc.F_CODE==='T'||doc.F_CODE==='O'){emit([doc.Location.latitude,doc.Location.longitude],doc._id)}}"
					}
				}
			}, {
				"_id" => "_design/localities_by_county",
				:views => {
					:all => {
						:map => "function(doc){if(doc.F_CODE==='T'||doc.F_CODE==='O'){emit(doc.FULL_COUNTY,doc._id)}}"
					}
				}
			}, {
				"_id" => "_design/features_by_name",
				:views => {
					:all => {
						:map => "function(doc){emit(doc.DEF_NAM,doc.F_CODE)}"
					}
				}
			}])

			roads_db.bulk_save([{
				"_id" => "_design/roads_by_location",
				:views => {
					:all => {
						:map => "function(doc){emit([null,doc.Centre.latitude,doc.Centre.longitude],doc._id);emit([null,doc.Min.latitude,doc.Min.longitude],doc._id);emit([null,doc.Max.latitude,doc.Max.longitude],doc._id);}"
					}
				}
			}, {
				"_id" => "_design/roads_by_location_in_locality",
				:views => {
					:all => {
						:map => "function(doc){emit([doc.Locality,doc.Centre.latitude,doc.Centre.longitude],doc._id);emit([doc.Locality,doc.Min.latitude,doc.Min.longitude],doc._id);emit([doc.Locality,doc.Max.latitude,doc.Max.longitude],doc._id);}"
					}
				}
			}, {
				"_id" => "_design/roads_by_location_in_district",
				:views => {
					:all => {
						:map => "function(doc){emit([doc.Local_Authority,doc.Centre.latitude,doc.Centre.longitude],doc._id);emit([doc.Local_Authority,doc.Min.latitude,doc.Min.longitude],doc._id);emit([doc.Local_Authority,doc.Max.latitude,doc.Max.longitude],doc._id);}"
					}
				}
			}, {
				"_id" => "_design/roads_by_location_in_county",
				:views => {
					:all => {
						:map => "function(doc){emit([doc.Cou_Unit,doc.Centre.latitude,doc.Centre.longitude],doc._id);emit([doc.Cou_Unit,doc.Min.latitude,doc.Min.longitude],doc._id);emit([doc.Cou_Unit,doc.Max.latitude,doc.Max.longitude],doc._id);}"
					}
				}
			}, {
				"_id" => "_design/roads_by_name",
				:views => {
					:all => {
						:map => "function(doc){emit(doc.Name,doc.Locality)}"
					}
				}
			}])

		end

	end

	class ONS

		def self.load
			ons_db = CouchRest.database!(ENV['ONS_DB'])
			# ons data from codepoint
			area_types = {
				"CTY" => / County$/,
				"DIS" => / District( \(B\))?$/,
				"DIW" => / Ward$/,
				"LBO" => / London Boro$/,
				"LBW" => / Ward$/,
				"MTD" => / District \(B\)$/,
				"MTW" => / Ward$/,
				"UTA" => / \(B\)$/,
				"UTE" => / ED$/,
				"UTW" => / Ward$/,
				"NHS_English_SHA" => nil,
				"NHS_English_PanSHA" => nil,
				"NHS_Scottish_Health_Boards" => nil,
				"NHS_NI_Health_Board" => nil
			}
			area_types.each do |type,pattern|
				docs = []
				csv = File.expand_path("../../data/codepo_gb/Doc/#{type}.csv", __FILE__)
				CSV.foreach(csv, headers: 'name,code') do |row|
					if row['code']
						doc = {
							"_id" => pattern ? row['code'] : row['name'], 
							:type => type.sub(/_/,' '),
							:full_name => pattern ? row['name'] : row['code'],
							:name => pattern ? row['name'].sub(pattern, '') : row['code']
						}
						docs.push(doc)
					end
				end
				puts "Loading #{docs.length} #{type} areas ..."
				result = ons_db.bulk_save(docs)
				puts "... done: #{result[0].inspect}"
			end
			# ons data from ons
			docs = []
			csv = File.expand_path("../../data/ons/CTRY12_GOR10_CTY12_LAD12_WD12_UK_LU.csv", __FILE__)
			CSV.foreach(csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
				doc = {
					"_id" => row['CTY12CD'], 
					:type => 'CTY',
					:name => row['CTY12NM']
				}
				docs.push(doc)
				doc = {
					"_id" => row['LAD12CD'], 
					:type => 'LAD',
					:name => row['LAD12NM']
				}
				docs.push(doc)
				doc = {
					"_id" => row['WD12CD'], 
					:type => 'WD',
					:name => row['WD12NM']
				}
				docs.push(doc)
			end
			puts "Loading #{docs.length} CTY, LAD & WD areas ..."
			result = ons_db.bulk_save(docs)
			puts "... done: #{result[0].inspect}"
		end

	end

	class Features
		# Field number  Field name  Full name           Format      Example
		# 1             SEQ         Sequence number	    Int (6)     86415
		# 2             KM_REF      Kilometre reference Char (6)    ST5265
		# 3             DEF_NAM     Definitive name     Char (60)   Felton
		# 4             TILE_REF    Tile reference      Char (4)    ST46
		# 5             LAT_DEG     Latitude degrees    Int (2)     51
		# 6             LAT_MIN     Latitude minutes    Float (3.1) 23.1
		# 7             LONG_DEG    Longitude degrees   Int (2)     2
		# 8             LONG_MIN    Longitude minutes   Float (3.1) 41
		# 9             NORTH       Northings           Int (7)     165500
		# 10            EAST        Eastings            Int (7)     352500
		# 11            GMT         Greenwich Meridian  Char (1)    W
		# 12            CO_CODE     County code         Char (2)    NS
		# 13            COUNTY      County name         Char (20)   N Som
		# 14            FULL_COUNTY Full county name    Char (60)   North Somerset
		# 15            F_CODE      Feature code        Char (3)    O
		# 16            E_DATE      Edit date           Char (11)   01-MAR-1993
		# 17            UPDATE_CO   Update code         Char (1)    l
		# 18            SHEET_1     Primary sheet no    Int (3)     172
		# 19            SHEET_2     Second sheet no     Int (3)     182
		# 20            SHEET_3     Third sheet no      Int (3)     0

		def self.load
			features_db = CouchRest.database!(ENV['FEATURES_DB'])
			features_headers = 'SEQ,KM_REF,DEF_NAM,TILE_REF,LAT_DEG,LAT_MIN,LONG_DEG,LONG_MIN,NORTH,EAST,GMT,CO_CODE,COUNTY,FULL_COUNTY,F_CODE,E_DATE,UPDATE_CO,SHEET_1,SHEET_2,SHEET_3'.split(',')
			feature_types = {
				'A' => 'Antiquity (non-Roman)',
				'F' => 'Forest or wood',
				'FM' => 'Farm',
				'H' => 'Hill or mountain',
				'R' => 'Antiquity (Roman)',
				'C' => 'City',
				'T' => 'Town',
				'O' => 'Other',
				'W' => 'Water feature',
				'X' => 'All other features'
			}

			csv = File.expand_path('../../data/gaz50k_gb/data/50kgaz2013.txt', __FILE__)
			docs = []

			CSV.foreach(csv, encoding:'iso-8859-1:utf-8', headers: features_headers, col_sep: ':') do |row|
				doc = row.to_hash
				doc['_id'] = row['SEQ']
				doc['LAT_DEG'] = row['LAT_DEG'].to_i
				doc['LAT_MIN'] = row['LAT_MIN'].to_f
				doc['LONG_DEG'] = row['LONG_DEG'].to_i
				doc['LONG_MIN'] = row['LONG_MIN'].to_f
				doc['NORTH'] = row['NORTH'].to_i
				doc['EAST'] = row['EAST'].to_i
			  doc['Location'] = Breasal::EastingNorthing.new(easting: doc['EAST'], northing: doc['NORTH'], type: :gb).to_wgs84
				doc['Type'] = feature_types[row['F_CODE']]
				docs.push(doc)
				if docs.length >= 10000
					puts "Loading #{docs.length} features ..."
					result = features_db.bulk_save(docs)
					puts "... done: #{result[0].inspect}"
					docs = []
				end
			end

			puts "Loading #{docs.length} features ..."
			result = features_db.bulk_save(docs)
			puts "... done: #{result[0].inspect}"
		end
	end

	class Roads
		# Table structure:

		# Column		Field name		Format		Example			Description

		# 1		Name			A*		ALRESFORD ROAD		Feature name
		# 2		Classification		A*		B3404			Road number classification
		# 3		Centx			I6		449590			X co-ord for centre point of road object
		# 4		Centy			I7		129430			Y co-ord for centre point of road object
		# 5		Minx			I6		448797			X co-ord for SW corner of the road object box
		# 6		Maxx			I6		450392			X co-ord for NE corner of road object box
		# 7		Miny			I7		129422			Y co-ord for SW corner of the road object box
		# 8		Maxy			I7		129510			Y co-ord for NE corner of road object box
		# 9		Settlement		A*		WINCHESTER		Town in which the centre of the object falls
		# 10		Locality		A*		St. John and All Saints	1990 boundaries description for the point at the centre of the object
		# 11		Cou_Unit		A*		Hampshire County	County in which the centre of the object falls
		# 12		Local Authority		A*		Winchester District	Local Authority in which the centre of the object falls
		# 13		Tile_10k		A6		SU42NE			1:10 000 tile reference for the centre point of the object
		# 14		Tile_25k		A4		SU42			1:25 000 tile reference for the centre point of the object
		# 15		Source			A*		Roads			Source of information

		def self.load
			roads_db = CouchRest.database!(ENV['ROADS_DB'])
			roads_headers = 'Name,Classification,Centx,Centy,Minx,Maxx,Miny,Maxy,Settlement,Locality,Cou_Unit,Local_Authority,Tile_10k,Tile_25k,Source'.split(',')

			csv = File.expand_path('../../data/gazlco_gb/Data/OS_Locator2013_2_OPEN.txt', __FILE__)
			docs = []

			CSV.foreach(csv, headers: roads_headers, col_sep: ':') do |row|
				doc = row.to_hash
				doc['Centx'] = row['Centx'].to_i
				doc['Centy'] = row['Centy'].to_i
			  doc['Centre'] = Breasal::EastingNorthing.new(easting: doc['Centx'], northing: doc['Centy'], type: :gb).to_wgs84
				doc['Minx'] = row['Minx'].to_i
				doc['Miny'] = row['Miny'].to_i
			  doc['Min'] = Breasal::EastingNorthing.new(easting: doc['Minx'], northing: doc['Miny'], type: :gb).to_wgs84
				doc['Maxx'] = row['Maxx'].to_i
				doc['Maxy'] = row['Maxy'].to_i
			  doc['Max'] = Breasal::EastingNorthing.new(easting: doc['Maxx'], northing: doc['Maxy'], type: :gb).to_wgs84
				docs.push(doc)
				if docs.length >= 10000
					puts "Loading #{docs.length} roads ..."
					result = roads_db.bulk_save(docs)
					puts "... done: #{result[0].inspect}"
					docs = []
				end
			end

			puts "Loading #{docs.length} roads ..."
			result = roads_db.bulk_save(docs)
			puts "... done: #{result[0].inspect}"
		end

	end

	class CodePoint

		def self.load
			codepoint_db = CouchRest.database!(ENV['CODEPOINT_DB'])
			codepoint_headers = 'Postcode,Positional_quality_indicator,Eastings,Northings,Country_code,NHS_regional_HA_code,NHS_HA_code,Admin_county_code,Admin_district_code,Admin_ward_code'.split(',')

			csv_dir = File.expand_path('../../data/codepo_gb/Data/CSV/', __FILE__)

			Dir.glob("#{csv_dir}/*.csv") do |csv|
				puts "Processing #{csv} ..."
				docs = []
				CSV.foreach(csv, headers: codepoint_headers) do |row|
					doc = row.to_hash
					# clean up the postcode
					postcode = row['Postcode']
					postcode.insert(4, ' ') unless postcode.include?(' ')
					postcode.gsub!(/\s+/, ' ')
					doc['_id'] = postcode
					doc['Eastings'] = row['Eastings'].to_i
					doc['Northings'] = row['Northings'].to_i
				  doc['Location'] = Breasal::EastingNorthing.new(easting: doc['Eastings'], northing: doc['Northings'], type: :gb).to_wgs84
					docs.push(doc)
				end
				if codepoint_db.all_docs({key: docs[0]['_id']})['rows'].empty?
					puts "... loading #{docs.length} postcodes ..."
					result = codepoint_db.bulk_save(docs)
					puts "... done: #{result[0].inspect}"
				else
					puts "... already loaded"
				end
			end
		end

	end

end

