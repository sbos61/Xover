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
		return @state
	end

	def lopen(fname, mode)
		@currMode= LogMode[ mode]
		if (@currMode==nil)
			puts 'Opening with rong mode!'
			exit -1
		end

		begin
			t= Time.now()														# create a daily file
			if fname.match(/(.*?)\.log/)										# save extension
				var= Regexp.last_match(1)
				fname= var+ "_"+t.strftime("%Y-%m-%d")+".log"
			end
			@fHdl = File.new( fname, "a+")
			lwrite("--------- Log file "+fname +" opened", "INFO")
			@inmemory= false

			@msgBuffer.each do |line|
				@fHdl.puts line
			end
			@fHdl.flush
			rcode= OK
		rescue
			@fHdl = File.new( fname+".2.log", "a+")
			lwrite("Cannot open std logfile "+fname+ "", "INFO")
			@inmemory= false

			@msgBuffer.each do |line|
				@fHdl.puts line
			end
			rcode= CRITICAL

			puts @state.to_s+ ": Cannot open log file /"+fname+"/"
			exit rcode
		end
		return rcode
	end

	def lwrite (msg, msgType)													# sub LogWrite ( $msg, $loglevel)
		begin
			if (msgType== nil)
				msgType = "INFO"
			end
			if ( LogMode[ msgType] <=  @currMode)
				t = Time.now
				line= t.strftime("%Y-%m-%d %H.%M.%S")+ " - "+msgType+" "+ msg
				if (@inmemory)
					@msgBuffer.push( line)
				else
					@fHdl.puts line
					@fHdl.flush
				end
			end
			return OK
		rescue
			t = Time.now
			line= t.strftime("%Y-%m-%d %H.%M.%S")+ " - ERR_ Log service internal error"+ msg
			if (@inmemory)
				@msgBuffer.push( line)
			else
				@fHdl.puts line
			end
			lclose()
			exit! (-1)															# abort completely
		end
	end

	def lclose ()
	  lwrite("--------- Log file closed: normal exit" , "INFO")
	  @fHdl.close
	end

end


end