require 'bundler/setup'
require File.expand_path('../lib/upload', __FILE__)

task :upload_ons do
	Upload::ONS.load
end

task :upload_features do
	Upload::Features.load
end

task :upload_roads do
	Upload::Roads.load
end

task :upload_codepoint do
	Upload::CodePoint.load
end