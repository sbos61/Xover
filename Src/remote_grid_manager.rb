######################################
#
# Configuration manager for Selenium Grid
# Currently only a stub
#
require 'yaml'


class RemoteGridManager
	def initialize( databaseFile)
		unless File.exist?(databaseFile)
			$alog.lwrite('Configuration file: ' +databaseFile +' not found. ', 'ERR_')   #
		end

		@db=Hash.new
		h= YAML.load(File.read(databaseFile))
		@db.merge!(h)
		@dbname= databaseFile[0..-5]+'_.yml'
		File.open(@dbname, 'w') do |f|
			s=@db.to_yaml( :Indent => 4, :UseHeader => true, :UseVersion => true )
#			YAML.dump
#			f.write s
		end
	end

	def reserve( browser)
		if (@db['browsers'][browser]==nil)
			$alog.lwrite('Browser : '+browser +' not defined in grid configuration ', 'ERR_')   #
		end
		hostName= @db['browsers'][browser][0]
		if hostName== nil
			$alog.lwrite('No host for browser : '+browser, 'ERR_')   #
		end
		return hostName																# set here reservaton info
	end

	def release( hostName)
	end

	def scan(browser)
	end
end

