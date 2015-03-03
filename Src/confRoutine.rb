################################################################################
#
#  Service transaction info( timeouts, names)
#
require 'mail'
require_relative 'send_msg.rb'
require_relative 'html_output.rb'
require_relative 'send_nsca.rb'
require_relative 'serv_conf_data.rb'
require_relative 'perfRoutine.rb'

def resText(e)
	resT= %w(PASS WARNING FAIL UNKNOWN)
	return resT[e]
end

################################################################################
#
#  Global Configuration struct init
#
class GlobConfData
	def initialize(file, mode)

		@fname=''																# file name, non path, no ext
		@confGlobFile= ''
		@servConfPath= ''

		@logFile= ''															# full-path file name
		@logMode= 'DEBG'
		@logPath= ''

		@dateTemplate= ''
		@dirDelim= ''
		@opSyst= ''
		if(OS.windows?)
			@dirDelim= '\\'
			@opSyst= 'Windows'
		else
			@dirDelim= '/'
			@opSyst='Linux'
		end

		@brwsrType= ''
		@brwsrProfile= ''
		@testMode= false														# test mode
		@hlmode= false															# headless mode
		@headless= nil
		@res='OK'

		@start= Time.now
#   --------------------------------------- HTML config
		@htmlOutFile= ''

#   --------------------------------------- # NSCA file part
		@nscaEnable=false
		@nscaExeFile=''
		@nscaConfigFile=''
		@nscaServer= ''
		@nscaPort= ''
		@newConn=false
		@conn=nil

#   --------------------------------------- #  Command file part
		@rwEnable= false
		@rwFile=''							# write directly to Nagios command queue

#   --------------------------------------- # Screen output control
		@screenEnable=true
		@screenShotEnable=false
		@screenShotFname=''
#   --------------------------------------- # Jmeter config file part
		@jmeterHome=''
		@javaHome=''

#   --------------------------------------- # runMode parms & timers
		@runMode=nil
		@pollTime=0
		@testDur=0
		@testRepeat=0
		@pageTimeOut=30						# default value
		@pageTimer
		
		@nServ= 0
		@scfd= Array.new

#   --------------------------------------- # mail send config
		@mailEnable=false
		@mailToAddress=''
		@mailFromAddress='WebMonitor@bosoconsulting.it'
		@mailSmpt=''
		@mailPort=''
		@mailUser=''
		@mailPwd=''
		@mail=NIL																# main mail object

		@iScenario=0															# count scenarios
#
#  actual start up
#
		if $alog ==nil
			$alog= LogRoutine::Log.new(OK, 'DEBG')								# open log file, if not open
		end
		@confGlobFile= file
		@hlmode= mode
		self.ParseConfFile( @confGlobFile)

		$alog.lopen(@logFile, @logMode)
		$alog.lwrite('Config data read from '+@confGlobFile, 'INFO')

		begin
			if(@hlmode== true)
				@headless = Headless.new(:dimensions => '1024x768x16')
				@headless.start
				$alog.lwrite('Headless mode driver opened', 'DEBG')
			end
		rescue
			msg= 'Cannot activate headless mode. '+ $!.to_s
			$alog.lwrite(msg, 'ERR_')
			$alog.lclose
			p msg																	# return message to Nagios
			exit!(UNKNOWN)
		end

		self.setUpOutput
	end

	attr_accessor :fname, :confGlobFile, :servConfPath, :logFile, :logMode, :logPath, :dateTemplate, :dirDelim, :opSyst
	attr_accessor :brwsrType, :brwsrProfile, :testMode, :hlmode, :headless, :res, :downLoadPath
#	attr_accessor :iScenario
	attr_reader   :scfd

#	attr_accessor :htmlOutFile
#	attr_accessor :nscaEnable, :nscaExeFile, :nscaConfigFile, :nscaServer, :nscaPort
#	attr_accessor :rwFile, :rwEnable, :newConn, :conn,:screenEnable, :screenShotEnable, :screenShotFname, :javaHome, :jmeterHome
	attr_reader   :runMode, :pollTime, :testDur, :testRepeat, :pageTimeOut, :mailEnable
				  #	attr_accessor :nServ
#	attr_reader   :mailToAddress, :mailFromAddress, :mailSmpt, :mailPort, :mailUser, :mailPwd
#	attr_accessor :mail

#### more complex methods

	def duration
		t =(Time.now- @start)
		return t
	end

	def scfdAdd( s)
		@scfd.push( s)
	end

################################################################################
#
#  Config File parsing( each service)
#
	def ParseGlobalConfData( sDataG)
	begin
		$alog.lwrite('Parsing Global Configuration started ', 'INFO')
# puts "var "+var+" value "+ value

		@logMode= 		sDataG['LogMode']
		@brwsrType= 	sDataG['Browser'][0..1].downcase								# normalize browser types
		case @brwsrType
			when 'ie'
				@brwsrName='Explorer'
			when 'ch'
				@brwsrName='Chrome'
			else
				@brwsrName='Firefox'
		end

		@brwsrProfile=	sDataG['Profile'] ? sDataG['Profile']: ''

		case sDataG['runMode'].downcase
			when 'plugin'		then @runMode= PLUGIN	# run mode: standalone or passive
			when 'passive'		then @runMode= PASSIVE
			when 'standalone' 	then @runMode= STANDALONE
			when 'cucumber'		then @runMode= CUCUMBER
			else
				$alog.lwrite('RunMode : '+sDataG['runMode'] +' not supported ', 'ERR_')   #
		end

		@pageTimeOut= sDataG['PageTO'].to_f						# values in seconds
		@pollTime= 	sDataG['pollTime']*60						  # input in minutes, move to seconds
		@testDur= 	sDataG['testDuration']*60

		@logPath= 	  sDataG['LogPath']
		@downLoadPath=File.expand_path(@logPath)      #
		@servConfPath=sDataG['ServConfPath']
		@dateTemplate=sDataG['DateTemplate']
		@javaHome= 	  sDataG['JavaHome']
		@jmeterHome=  sDataG['JmeterHome']

		if sDataG['HTMLfile']['HTMLenable']
			@htmlOutFile=  sDataG['HTMLfile']['HTMLoutFile']
		end

		if sDataG['NSCA']
			@nscaEnable=	sDataG['NSCA']['NSCAenable']
			@nscaExeFile= 	sDataG['NSCA']['NSCAexeFile']
			@nscaConfigFile=sDataG['NSCA']['NSCAconfigFile']
			@nscaServer= 	sDataG['NSCA']['NSCAserver']
			@nscaPort=  	sDataG['NSCA']['NSCAport']

		end

		if sDataG['ResFile']['ResFileEnable']
			@rwFile= sDataG['ResFile']['ResFile']
		end

		@screenEnable= sDataG['screenEnable']
		@screenShotEnable= sDataG['screenShotEnable']

		if sDataG['mail']['mailEnable']
			@mailToAddress =  sDataG['mail']['mailToAddress']
			@mailFromAddress= sDataG['mail']['mailFromAddress']
			@mailUser=        sDataG['mail']['mailUser']
			@mailPwd =        sDataG['mail']['mailPwd']
			@mailSmpt=        sDataG['mail']['mailSmpt']
			@mailPort=        sDataG['mail']['mailPort']
		end

		if(@rwEnable == true) &&(@rwFile== '')									# if command file, check for file name
			msg= 'Command file not set'
			$alog.lwrite(msg, 'ERR_')
			p msg
			exit! UNKNOWN														# file name not set: fatal error
		end

		if(@nscaEnable == true) &&(@nscaExeFile== '')							# if NSCA, check for command file name
			msg= 'NSCA command file not set'
			$alog.lwrite(msg, 'ERR_')
			p msg
			exit! UNKNOWN														# Cannot read file: fatal error
		end

		index = @confGlobFile.rindex('.')										# take conf file
		if(index) then
			cnfname= @confGlobFile[0 , index]									# strip off extension
		end

		index = cnfname.rindex(/[\\,\/]/)                                       # valid fro Wind & linux
		if(index) then															# strip off path
			cnfname= cnfname[index+1, 9999]
		end
#   @fname= cnfname																# save name, no path, no ext
		@logFile= @logPath+ cnfname+ '.log'										# calculate log file full name

		t= Time.now()															# create a daily file for HTML output
		if @htmlOutFile.match(/(.*?)\.htm?/)									# strip extension
			var= Regexp.last_match(1)
			@htmlOutFile=var+ '_'+t.strftime("%Y-%m-%d")+'.html'
		end


		ret= OK
	rescue
		msg= 'Global config file error: '+$!.to_s
		$alog.lwrite(msg, 'ERR_')
		p msg
		ret= UNKNOWN															# Cannot read file: fatal error
	end
	$alog.lwrite('Global Configuration parsed: code '+ ret.to_s, 'INFO')
	return ret



end

	def setupServiceConf( serData, service)

		begin

			$alog.lwrite('Service ConfData started for '+service, 'INFO')
			locScfd= ServConfData.new
			locStxd= ServTxData.new

			locStxd.nTX=0

			case serData['TestType'].downcase
				when 'seleniumide'	then locScfd.testType= SELENIUM
				when 'jmeter'		then locScfd.testType= JMETER
				when 'cucumber'		then locScfd.testType= CUCUMBER
				else
					$alog.lwrite('Test type : '+serData['TestType'] +' not supported ', 'ERR_')
			end

			locScfd.nagServer= serData['NagiosServer']
			locScfd.nagService= serData['NagiosService']

			locScfd.warnTO= serData['WarnTO'].to_f
			locScfd.critTO= serData['CritTO'].to_f

			if (serData['OpTable']!=nil)
				serData['OpTable'].each do |opt|
					locScfd.opTableAdd( opt)
				end
			end

# TODO Service TX management
# 				when 'TXname'
#											locStxd.nTX +=1
#											locStxd.txNameAdd( value)
#				when 'TXWarnTO'			then locStxd.txWarnTOAdd( value.to_f)
#				when 'TXCritTO'			then locStxd.txCritTOAdd( value.to_f)
#		locScfd.TxDataAdd(locStxd)
			self.scfdAdd( locScfd)
			@nServ +=1
			$alog.lwrite('Service Config Data parsed ', 'INFO')
			return OK

		rescue
			msg= 'Service config file error: '+$!.to_s
			$alog.lwrite(msg, 'ERR_')
			p msg
			return UNKNOWN															# Cannot read file: fatal error
		end
	end

	def headlessMgr
		begin
			if(@hlmode== true)
				@headless = Headless.new(:dimensions => '1024x768x16')
				@headless.start
			end
		rescue
			msg= 'Cannot activate headless mode. '+ $!.to_s
			$alog.lwrite(msg, 'ERR_')
			$alog.lclose
			p msg                                                                   # return message to Nagios
			exit!(UNKNOWN)
		end
	end

	def XOtearDown()

		msgLog ='Durata test: '+ sprintf('%.3f',self.duration)+ 's'
		$alog.lwrite(msgLog, 'INFO')
		self.sendServResClose
		$brws.XOclose
		if(@hlmode== true)
			@headless.destroy
		end

		$alog.lclose
	end

################################################################################
#
#  Main configuration procedures
#
	def ParseConfFile( confFile)
		begin
	#		fh = File.new( confFile, 'r')
			sData= YAML.load(File.read(confFile))
			ret= 'OK'

			self.ParseGlobalConfData( sData['GlobalConf'])
			sData['StartServiceConf'].each do |sConf|
				self.setupServiceConf( sConf, sConf['name'])
			end
		rescue
			msg= 'Service config file error: '+$!.to_s
			$alog.lwrite(msg, 'ERR_')
			p msg
			return UNKNOWN															# Cannot read file: fatal error
		end

		if((@runMode== nil)||(@runMode== PASSIVE))						# default is old stype passive mode
			@runMode= PASSIVE
			@testRepeat=1
			@testDur=1
			@pollTime=1
		elsif( @runMode== PLUGIN)
			@testRepeat=1
			@testDur=1
			@pollTime=1
			@nServ=1															# in plugin mode, only one service allowed
			@screenEnable=false
		elsif(  @runMode== CUCUMBER)
			@testRepeat=1
			@testDur=1
			@pollTime=1
			@nServ=1															# in plugin mode, only one service allowed
		elsif(( @pollTime==0)||(@testDur==0))
			raise 'RunMode configuration error: '+@pollTime.to_s+' , '+@testDur.to_s

		else
			@runMode= STANDALONE
			@testRepeat=(@testDur / @pollTime).round
			@pollTime= @pollTime											# move to seconds
		end

		self.headlessMgr()

		return ret
	end

################################################################################
#
#		Calc service result
#
################################################################################
	def setUpOutput( )
		opt={
			:address				=> @mailSmpt,
			:port					=> @mailPort.to_i,
			:domain					=> 'localhost',
			:user_name				=> @mailUser,
			:password				=> @mailPwd,
			:authentication			=> 'plain',
			:enable_starttls_auto	=> true
		}
		@mail= SendMsg.new(opt)
		@htmlHdl=HtmlOutput.new(@logPath+@htmlOutFile, @confGlobFile, true, @runMode) 	#setSpacer=true

	end


	def setUpServiceRes( srvName, runMode, testType)
		$pfd=PerfData.new(@logPath+srvName+'.jtl', false, runMode, testType)	# get results file name from service name
	end


	def calcServiceResCucumber(locService, fname)							# only valid for Cucumber
		locServer= @brwsrName
		locService= @iScenario.to_s+' '+fname+' '+locService
		@iScenario +=1

		iServ=0
		locWarnTO= @scfd[iServ].warnTO
		locCritTO= @scfd[iServ].critTO
		$pfd.perfClose(locService, $brws.url.to_s)
		$pfd.applResMsg= $pfd.calcPerfData(iServ, locWarnTO, locCritTO)

		$pfd.append2JtlTotal()
		return self.sendServRes( locServer, locService, 0, $pfd.applResMsg, $pfd.retState) # process output
	end

	def sendServRes(nagserver, nagservice, iTest, msg,  state)

		resMsg=  resText($pfd.retState)
		msgLine= Time.now.strftime("%Y-%m-%d %H.%M.%S ")+' Service '+nagservice+' closed: run #'+iTest.to_s+' State '+resMsg

		@htmlHdl.addHtmlData(nagserver, nagservice, $pfd.retState, msg)
		ret= state

		if(@screenEnable==true)
			p msgLine
		end
		if(@nscaEnable==true)
			begin
				if((@newConn)==false)
					@conn= SendNSCA.new(:command => @nscaExeFile,
											 :host => @nscaServer,
											 :port => @nscaPort,
											 :confFile => @nscaConfigFile)
					@newConn=true
				end

				ret= @conn.sendNSCA(nagserver, nagservice, msg, state)
			rescue
				msg= 'Cannot send NSCA data to server '+ @nscaServer+': '+ $!.to_s
				$alog.lwrite(msg, 'ERR_')
				$alog.lclose
				p msg																# return message to Nagios
				return(UNKNOWN)
			end
		end
		if(@rwEnable==true)
			begin
				ts=(Time.now.to_f ).to_i 											# read time stamp
				# write result
				line= '['+ts.to_s+'] PROCESS_SERVICE_CHECK_RESULT;'+nagserver+';'+nagservice+';'+state.to_s+';'+msg.tr("\n",' ')
				$alog.lwrite(line, 'DEBG')                                          # fprintf(command_file_fp,"[%lu] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s\n",(unsigned long)check_time,host_name,svc_description,return_code,plugin_output);

				fcmdh = File.new( @rwFile, 'a+')
				fcmdh.puts(line)
				fcmdh.flush
				fcmdh.close
				ret= state
			rescue
				msg= 'Cannot write to command file '+ @rwFile+': '+ $!.to_s
				$alog.lwrite(msg, 'ERR_')
				$alog.lclose
				return(UNKNOWN)
			end
		end
#																										# HTML output UNCONDITIONAL
		if((@mailEnable==true) &&(state !=OK))															# send mail only with alarms/errors etc
			@mail.sendMailMsg( msgLine)
		end
		return state
	end

	def sendServResClose
		@htmlHdl.closeHtmlData
		begin
			if((@mailEnable==true) &&(state !=OK))															# send mail only with alarms/errors etc
				@mail.deliverMailMsg(@logPath, @htmlOutFile )
			end
		rescue
			msg= 'Cannot send mail with text: '+ $!.to_s
			$alog.lwrite(msg, 'ERR_')
		end

	end

end

