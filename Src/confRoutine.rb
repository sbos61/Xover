################################################################################
#
#  Service transaction info( timeouts, names)
#
require 'mail'
require_relative 'confRoutine2.rb'
require_relative 'definitions.rb'
require_relative 'htmlResultOutput.rb'
require_relative 'perfRoutine.rb'
require_relative 'remote_grid_manager.rb'
require_relative 'send_msg.rb'
require_relative 'send_nsca.rb'

# require_relative 'serv_conf_data.rb'

def resText(e)
	resT= %w(PASS WARNING FAIL UNKNOWN)
	return resT[e]
end

################################################################################
#
#  Global Configuration struct init
#
class GlobConfData
	def initialize( files, mode)
		@confGlobFile= files[0]
		@runId=files[1]                                                        # save conf  filename
		self.initInfo( @confGlobFile, mode)
#
#  actual start up
#
		if $alog ==nil
			$alog= LogRoutine::Log.new(OK, 'DEBG')								# open log file, if not open
		end
		self.installConfData('../Xover/cfg/sysinstall.yml')
		self.parseConfFile( @confGlobFile)                                      # save runId

		@gridMgr= RemoteGridManager.new( '../Xover/cfg/grid_conf.yml')	# seek for host
		@remoteHostName= @gridMgr.reserve( @brwsrName)

		self.setRunFileNames(@remoteHostName, @runId, @confGlobFile)
		$alog.lopen(@logFile, @logMode)											# log routine add date to file name
		$alog.lwrite('Config data read from '+@confGlobFile, 'INFO')
	end
#
#
#
	def initInfo( file, mode)
		@fname=''																# file name, non path, no ext
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
		@brwsrContentTypes= ''
		@brwsrIeNativeEvents= false

		@proxy= nil
		@testMode= false														# test mode
		@hlmode= mode															# headless mode
		@headless= nil
		@res='OK'

		@start= Time.now
#   --------------------------------------- HTML config
		@htmlOutFile= ''
		@report_url= ''
		@report_path= ''

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
		@servConfData= Array.new

		@mailInfo=nil
#   --------------------------------------- # NSCA file part
		@nscaInfo=nil

		@iScenario=0															# count scenarios
	end

	attr_accessor :fname, :confGlobFile, :servConfPath, :logFile, :logMode, :logPath, :dateTemplate, :dirDelim, :opSyst
	attr_accessor :brwsrType, :brwsrProfile, :testMode, :hlmode, :headless, :res, :downLoadPath, :proxy
	attr_reader   :report_url, :reportUrlBase, :brwsrContentTypes, :brwsrIeNativeEvents, :report_path, :resource_url, :logURL
	attr_accessor :servConfData, :iScenario
	attr_reader   :runMode, :runId, :pollTime, :testDur, :testRepeat, :pageTimeOut, :mailEnable

#### more complex methods
#
	def duration
		t =(Time.now- @start)
		return t
	end
##########
#
	def setRunFileNames(hostName, runID, confFile)
		runID+='/'
		@report_path= @report_path+runID

		@htmlOutFile= @report_path+ @xoRepName+  '.html'
		@reportUrlBase =  @project+@installData['repDir']+runID
		@report_url = @reportUrlBase+  @xoRepName+ '.html'
		@logPath= @logDir+runID 									# file basolute name
		@logFile= @logPath+ @xoRepName+ '.log'
		@logURL=  @project+@installData['logDir']+runID + @xoRepName+ '.log'

	end

	def getUrlFromFileName (fname)
		return @reportUrlBase+ File.basename( fname)
	end

################################################################################
#
#  Config File & Name setting parsing( each service)
#
	def installConfData(fname)
		$alog.lwrite('Parsing Installation info started ', 'INFO')
		@installData= Hash.new
		h= YAML.load(File.read(fname))
		@installData.merge!(h)
		pwd=Dir.pwd
		@project= '/'+pwd.split('/')[-1]       							#current directory name
		@report_url= @project +@installData['repDir']
		@report_path= pwd+ @installData['repDir']+'/'

		@logDir= pwd+ @installData['logDir']
		@resource_url= '/Xover/resources/'
		@xoRepName= @installData['xoRepName']
	end
################################################################################
#
#  Config File parsing( each service)
#
	def parseGlobalConfData( sDataG)
		begin
			$alog.lwrite('Parsing Global Configuration started ', 'INFO')
# puts "var "+var+" value "+ value

			@logMode= 		sDataG['LogMode']

			case sDataG['runMode'].downcase
				when 'plugin'		then @runMode= PLUGIN	# run mode: standalone or passive
				when 'passive'		then @runMode= PASSIVE
				when 'standalone' 	then @runMode= STANDALONE
				when 'cucumber'		then @runMode= CUCUMBER
				when 'testnobrowser' then @runMode= TEST
				else
					$alog.lwrite('RunMode : '+sDataG['runMode'] +' not supported ', 'ERR_')   #
			end
			if(sDataG['proxy'])
				@proxy= sDataG['proxy']
			else
				@proxy= nil
			end
			@pageTimeOut= sDataG['PageTO'].to_f							# values in seconds
			@pollTime=	  sDataG['pollTime']*60						  	# input in minutes, move to seconds
			@testDur= 	  sDataG['testDuration']*60

			@logPath=		'.'+ @installData['logDir']
			@reportPath=	'.'+ @installData['repDir']
			@downLoadPath=	File.expand_path(@logPath)
			@servConfPath=	'.'+ @installData['cfgDir']
			@dateTemplate=	@installData['DateTemplate']
			@javaHome=		@installData['JavaHome']
			@jmeterHome=	@installData['JmeterHome']

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

			if(serData==nil)
				$alog.lwrite('No Service ConfData found for '+service, 'INFO')
				return OK
			end
			$alog.lwrite('Service ConfData started for '+service, 'INFO')
			locServConfData= serData

			case locServConfData['testType'].downcase
				when 'seleniumide'	then locServConfData['testType']= SELENIUM
				when 'jmeter'		then locServConfData['testType']= JMETER
				when 'cucumber'		then locServConfData['testType']= CUCUMBER
				else
					$alog.lwrite('Test type : '+serData['TestType'] +' not supported ', 'ERR_')
			end
			@brwsrType= 	locServConfData['browser'][0..1].downcase								# normalize browser types
			case @brwsrType
				when 'ie'
					@brwsrName='Explorer'
					@brwsIeNativeEvents= locServConfData['ieNativeEvents'] ? true: false
				when 'ch'
					@brwsrName='Chrome'
				when 'ed'
					@brwsrName='Edge'
				else
					@brwsrName='Firefox'
					@brwsrProfile=	locServConfData['profile'] ? locServConfData['profile']: ''
			end
			@brwsrContentTypes= locServConfData['contentTypes'] ? locServConfData['contentTypes']: ''

			$alog.lwrite('Reading Service Timeout for '+service, 'INFO')

			locServConfData['warnTO']= serData['warnTO'].to_f
			locServConfData['critTO']= serData['critTO'].to_f

			$alog.lwrite('Reading Service TX Timeout for '+service, 'INFO')
			if serData['txTable']
				serData['txTable'].each do |tx|
					tx['TXWarnTO']= tx['TXWarnTO'].to_f
					tx['TXCritTO']= tx['TXCritTO'].to_f
				end
			end

			@nServ +=1
			@servConfData << locServConfData
			$alog.lwrite('Service Config Data parsed ', 'INFO')
			return OK
		rescue
			msg= 'Service config file error: '+$!.to_s
			$alog.lwrite(msg, 'ERR_')
			p msg
			exit -1
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

	def tearDown()

		msgLog ='Durata test: '+ sprintf('%.3f',self.duration)+ 's'
		$alog.lwrite(msgLog, 'INFO')
		self.sendServResClose
		if(@runMode!=TEST)
 			$brws.XOclose
			if(@hlmode== true)
				@headless.destroy
			end
		end
		$alog.lclose
	end

################################################################################
#
#  Main configuration procedures
#
	def parseConfFile( confFile)
		begin
	#		fh = File.new( confFile, 'r')
			sData= YAML.load(File.read(confFile))
			ret= 'OK'

			self.parseGlobalConfData( sData['GlobalConf'])
			self.setOutputConf(sData['outputInfo'])
			sData['serviceConf'].each do |sConf|
				self.setupServiceConf( sConf, sConf['service'])
			end
		rescue
			msg= 'Service config file error: '+$!.to_s+"\n"+caller
			$alog.lwrite(msg, 'ERR_')
			p msg
			return UNKNOWN														# Cannot read file: fatal error
		end

		if(@runMode== nil)
#			@runMode= PASSIVE
		end

		if((@runMode== PASSIVE)|| (@runMode== TEST))								# default is old stype passive mode
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
	end
end

