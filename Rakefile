require 'bundler/setup'
require 'dotenv/tasks'
require 'zip'
require File.expand_path('../lib/upload', __FILE__)

task :unzip_data do
	DATA_DIR = File.expand_path('../data/', __FILE__)
	['ons.zip', 'gaz50k_gb.zip', 'gazlco_gb.zip', 'codepo_gb.zip'].each do |zip|
		Zip::File.open(File.expand_path(zip, DATA_DIR)) do |zipfile|
			zipfile.each do |file|
				path = File.expand_path(file.name, DATA_DIR)
			    zipfile.extract(file, path) unless file.name =~ /^__MACOSX/ || File.exists?(path)
			end
		end
	end
end

task :upload_designs => [:dotenv, :unzip_data] do
	Upload::Designs.load
end

task :upload_ons => [:dotenv, :unzip_data] do
	Upload::ONS.load
end

task :upload_features => [:dotenv, :unzip_data] do
	Upload::Features.load
end

task :upload_roads => [:dotenv, :unzip_data] do
	Upload::Roads.load
end

task :upload_codepoint => [:dotenv, :unzip_data] do
	Upload::CodePoint.load
end

task :upload => [:upload_designs, :upload_ons, :upload_features, :upload_roads, :upload_codepoint] do
end
