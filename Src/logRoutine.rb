################################################################################
# LOG definitions
#	NB
#
#
LogMode = {
	'ERR_'		=> 0,															# production mode
	'WARN'		=> 1,															# debug mode
	'INFO'		=> 2,															# test mode
	'DEBG'		=> 3															# debug mode
}
#
#	 ExitStatus	 = {
#		 'OK'		 => '0',
#		 'WARNING'	 => '1',
#		 'CRITICAL'	 => '2',
#		 'UNKNOWN'	 => '3'
#	 }
################################################################################
# LOG routines
#	NB
#
module LogRoutine

class Log
	def initialize ( status, mode)
		@state = status
		@inmemory= true
		@msgBuffer= Array.new
		@currMode= LogMode[ mode]
		@modeStr= mode
		@fName= ''
		return @state
	end

	def lwrite2file( msg, msgType)
		t= Time.now()
		line= t.strftime("%Y-%m-%d %H.%M.%S")+ ' - '+msgType+' '+ msg
		@fHdl.puts line
		@fHdl.flush
	end

	def lwrite2buf( msg, msgType)
		t= Time.now()
		line= t.strftime("%Y-%m-%d %H.%M.%S")+ ' - '+msgType+' '+ msg
		@msgBuffer.push( line)
	end

	def lopen(fname, mode)
		if !@inmemory
			self.lwrite2file('Double opening for logfile', 'INFO')
		end
		@currMode= LogMode[ mode]
		@modeStr= mode
		if (@currMode==nil)
			puts 'Opening with wrong mode!'
			exit -1
		end

		begin
			if(@fName=='')
				t= Time.now()														# create a daily file
				if fname.match(/(.*?)\.log/)										# save extension
					var= Regexp.last_match(1)
					fname= var+ '_'+t.strftime("%Y-%m-%d")+'.log'
				end
				@fHdl = File.new( fname, 'a+')
				self.lwrite2file('--------- Log file '+fname +' opened', 'INFO')
				@inmemory= false
				@fName= fname
			else
				@fHdl = File.new( @fName, 'a+')
				self.lwrite2file('--------- REOPENING file '+@fName +'!!', 'INFO')
				@inmemory= false

			end
			@msgBuffer.each do |line|
				@fHdl.puts line
			end
			@fHdl.flush
			rcode= OK
		rescue
			@fHdl = File.new( fname+'.2.log', 'a+')
			self.lwrite2file('Cannot open std logfile '+fname, 'INFO')
			@inmemory= false
			@msgBuffer.each do |line|
				@fHdl.puts line
			end
			rcode= CRITICAL

			puts @state.to_s+ ': Cannot open log file /'+fname+'/'
			exit rcode
		end
		return rcode
	end

	def lwrite (msg, msgType)													# sub LogWrite ( $msg, $loglevel)
		begin
			if (msgType== nil)
				msgType = 'INFO'
			end
			if ( LogMode[ msgType] <=  @currMode)
				t = Time.now

				if (@inmemory)
					if @fName==''
						self.lwrite2buf( msg, msgType)
					else
						@fHdl = File.new( @fName, 'a+')
						self.lwrite2file( msg, msgType)
					end
				else
					self.lwrite2file( msg, msgType)
				end
			end
			return OK
		rescue
			t = Time.now
			line= t.strftime("%Y-%m-%d %H.%M.%S")+ ' - ERR_ Log service internal error: '+ msg
			if (@inmemory)
				@msgBuffer.push( line)
			else
				@fHdl.puts line
			end
			p line
			exit! (-1)															# abort completely
		end
	end

	def lclose ()
	  	self.lwrite('--------- Log file closed: normal exit' , 'INFO')
		@fHdl.close
		@inmemory= true
	end

end


end