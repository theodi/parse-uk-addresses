require 'csv'
require 'couchrest'
require 'breasal'

ons = {}
# main admin areas
ons_csv = File.expand_path('../../data/ons/CTRY12_GOR10_CTY12_LAD12_WD12_UK_LU.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['CTRY12CD']] = row['CTRY12NM']
	ons[row['CTY12CD']] = row['CTY12NM']
	ons[row['LAD12CD']] = row['LAD12NM']
	ons[row['WD12CD']] = row['WD12NM']
end
# PSHAs
ons_csv = File.expand_path('../../data/ons/PSHA_2012_EN_NC.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['PSHA12CD']] = row['PSHA12NM']
end
# SHAs
ons_csv = File.expand_path('../../data/ons/SHA_2012_EN_NC.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['SHA12CD']] = row['SHA12NM']
end
# HBs
ons_csv = File.expand_path('../../data/ons/HB_2012_SC_NC.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['HB12CD']] = row['HB12NM']
end
# LHBs
ons_csv = File.expand_path('../../data/ons/LHB_2012_WA_NC.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['LHB12CD']] = row['LHB12NM']
end
# LHBs
ons_csv = File.expand_path('../../data/ons/LHB_2012_WA_NC.csv', __FILE__)
CSV.foreach(ons_csv, encoding:'iso-8859-1:utf-8', headers: :first_row) do |row|
	ons[row['LHB12CD']] = row['LHB12NM']
end

codepoint_db = CouchRest.database!("http://127.0.0.1:5984/codepoint")
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
		postcode.gsub(/\s+/, ' ')
		doc['_id'] = postcode
		doc['Eastings'] = row['Eastings'].to_i
		doc['Northings'] = row['Northings'].to_i
	  doc['Location'] = Breasal::EastingNorthing.new(easting: doc['Eastings'], northing: doc['Northings'], type: :gb).to_wgs84
	  doc['Country']  = { code: row['Country_code'],        name: ons[row['Country_code']] }
	  doc['County']   = { code: row['Admin_county_code'],   name: ons[row['Admin_county_code']] } unless row['Admin_county_code'] == ''
	  doc['District'] = { code: row['Admin_district_code'], name: ons[row['Admin_district_code']] }
	  doc['Ward']     = { code: row['Admin_ward_code'],     name: ons[row['Admin_ward_code']] }
	  doc['NHS_regional_HA'] = { code: row['NHS_regional_HA_code'], name: ons[row['NHS_regional_HA_code']] } unless row['NHS_regional_HA_code'] == ''
	  doc['NHS_HA']   = { code: row['NHS_HA_code'],         name: ons[row['NHS_HA_code']] } unless row['NHS_HA_code'] == ''
		docs.push(doc)
	end
	puts "... loading #{docs.length} postcodes ..."
	result = codepoint_db.bulk_save(docs)
	puts "... done: #{result[0].inspect}"
end

