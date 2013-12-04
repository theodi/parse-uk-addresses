require 'bundler/setup'
require 'dotenv/tasks'
require File.expand_path('../lib/upload', __FILE__)

task :upload_designs => :dotenv do
	Upload::Designs.load
end

task :upload_ons => :dotenv do
	Upload::ONS.load
end

task :upload_features => :dotenv do
	Upload::Features.load
end

task :upload_roads => :dotenv do
	Upload::Roads.load
end

task :upload_codepoint => :dotenv do
	Upload::CodePoint.load
end