require 'bundler/setup'
require File.expand_path('../lib/upload', __FILE__)

task :upload_roads do
	Upload::Roads.load
end

task :upload do
	Upload::CodePoint.load
end