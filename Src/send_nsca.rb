#!/usr/local/bin/ruby
################################################################################
#
#     use external send_nsca
#

class SendNSCA
	def initialize( args)
		@command= args[:command]
		@hostname= ' -H '+args[:host]+' '
		@timeOut=10
		@nscaConfigFile=' -c '+args[:confFile]+' '
		@port= ' -p '+args[:port]+' '
		@nagserver=''
		@nagservice=''
		@data=''
		@status=0
		@fullCmd=@command+@hostname+ @port+ ' -to '+@timeOut.to_s+@nscaConfigFile
		@resString=''
	end

	def sendNSCA(nagserver, nagservice, data, status)
		@resString= nagserver+"\t"+ nagservice+"\t" +status.to_s+"\t"+data+"\n"

		$alog.lwrite(@resString, 'DEBG')
		Open3.popen3(@fullCmd) do |stdin, stdout, stderr, wait_thr| 				# use stdin example
			stdin.write(@resString)
			stdin.close_write

			begin Timeout::timeout(5) do
				sendMsg= stdout.read
				procStatus= wait_thr.value
				if(procStatus.exitstatus!=0)
					$alog.lwrite(sendMsg, 'ERR_')
				else
					$alog.lwrite(sendMsg, 'DEBG')
				end
			end
			return(OK)
			rescue Timeout::Error
#			rescue
				$alog.lwrite('Timeout error sending to NSCA server: '+ $!.to_s, 'ERR_')
				return(UNKNOWN)
			end
		end
	end
end
