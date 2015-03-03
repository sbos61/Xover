
################################################################################
#
#		Mail sending management
#
class SendMsg
	def initialize(options)

		Mail.defaults do
			delivery_method :smtp, options
		end
		@msgBody=''
		@htmlOut=false
	end

	def sendMailMsg( text)
		if(text !='')
			@msgBody= @msgBody+"\n"+ text
		end
	end

	def deliverMailMsg(fpath, fname)
		@msgBody ||=''
		if(@msgBody=='')
			@msgBody='No errors reported'
		end
		msg=@msgBody
		myMail = Mail.deliver do
			to 		$gcfd.mailToAddress
			from 	$gcfd.mailFromAddress
			subject 'Automatic Alerting Mail from Crossover'
			body 	msg

			html_part do
				content_type 'text/html; charset=UTF-8'
				body  File.read(fpath+fname)
			end
		end
		$alog.lwrite('Mail message sent', 'DEBG')
	end
end

