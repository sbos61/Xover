# encoding: UTF-8
################################################################################
#
#		Calc service result
#
################################################################################
class GlobConfData

	def setOutputConf(sDataG)
		if sDataG['htmlInfo']['HTMLenable']
			@htmlOutFile=  sDataG['htmlInfo']['HTMLoutFile']
		end

		if sDataG['htmlInfo']['HTMLindexFile']
			@htmlIndexFile=  sDataG['HTMLfile']['HTMLindexFile']
			@htmlIndexFileFlag= true
		end
		if sDataG['resFile']['ResFileEnable']
			@rwFile= sDataG['resFile']['ResFile']
		end


		@screenEnable= sDataG['screenInfo']['screenEnable']
		@screenShotEnable= sDataG['screenInfo']['screenShotEnable']


		@mailInfo=  sDataG['mailInfo']
		@nscaInfo= sDataG['nscaInfo']

		if(@rwEnable == true) &&(@rwFile== '')									# if command file, check for file name
			msg= 'Command file not set'
			$alog.lwrite(msg, 'ERR_')
			p msg
			exit! UNKNOWN														# file name not set: fatal error
		end

		if(@nscaInfo && (@nscaInfo['nscaEnable'] == true) &&(@nscaInfo['nscaExeFile']== ''))							# if NSCA, check for command file name
			msg= 'NSCA command file not set'
			$alog.lwrite(msg, 'ERR_')
			p msg
			exit! UNKNOWN														# Cannot read file: fatal error
		end

#			cnfname= File.basename(@confGlobFile, '.yml')
#			@logFile= @logPath+'/'+ File.basename( cnfname+ '.log' )				# calculate log file full name
#			t= Time.now()															# create a daily file for HTML output

	end

	def setUpOutput( )
		opt={
			:address				=> @mailInfo['mailSmpt'],
			:port					=> @mailInfo['mailPort'].to_i,
			:domain					=> 'localhost',
			:user_name				=> @mailInfo['mailUser'],
			:password				=> @mailInfo['mailPwd'],
			:authentication			=> 'plain',
			:enable_starttls_auto	=> true
		}
		@mail= SendMsg.new(opt)
		@htmlHdl=HtmlResultOutput.new(@htmlOutFile, @confGlobFile, true, :cucumber, :append) 	#setSpacer=true
	end

	def setUpServiceRes( srvName, runMode, testType)
		$pfd=PerfData.new(@logPath+srvName+'.jtl', false, runMode, testType)			# get results file name from service name
	end

	def calcServiceResCucumber(locService, fname)										# only valid for Cucumber
		locServer= @brwsrName
		locService= @iScenario.to_s+' '+fname+'<br>'+locService
		@iScenario +=1

		iServ=0
		locWarnTO= @servConfData[iServ]['warnTO']
		locCritTO= @servConfData[iServ]['critTO']
		$pfd.perfClose(locService, $brws.url.to_s)
		$pfd.applResMsg= $pfd.calcPerfData(iServ, locWarnTO, locCritTO)

		$pfd.append2JtlTotal()
		return self.sendServRes( locServer, locService, 0, $pfd.applResMsg, $pfd.retState) # process output
	end

	def sendServRes(server, service, iTest, msg,  state)

		resMsg=  resText($pfd.retState)
		msgLine= Time.now.strftime("%Y-%m-%d %H.%M.%S ")+' Service '+service+' closed: run #'+iTest.to_s+' State '+resMsg

		@htmlHdl.addHtmlResultData(server, service, $pfd.retState, msg)
		ret= state

		if(@screenEnable==true)
			p msgLine
		end
		if (@nscaInfo&& @nscaInfo['NSCAenable'])
			begin
				if((@newConn)==false)
					@conn= SendNSCA.new(:command => @nscaExeFile,
										:host => @nscaServer,
										:port => @nscaPort,
										:confFile => @nscaConfigFile)
					@newConn=true
				end

				ret= @conn.sendNSCA(server, service, msg, state)
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
				line= '['+ts.to_s+'] PROCESS_SERVICE_CHECK_RESULT;'+server+';'+service+';'+state.to_s+';'+msg.tr("\n",' ')
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
#																						# HTML output UNCONDITIONAL
		if(((@mailInfo) && @mailInfo['mailEnable']==true) &&(state !=OK))						# send mail only with alarms/errors etc
			@mail.sendMailMsg( msgLine)
		end
		return state
	end

	def sendServResClose
		@htmlHdl.closeHtmlData
		begin
			if((@mailEnable==true) &&(state !=OK))											# send mail only with alarms/errors etc
				@mail.deliverMailMsg(@logPath, @htmlOutFile )
			end
		rescue
			msg= 'Cannot send mail with text: '+ $!.to_s
			$alog.lwrite(msg, 'ERR_')
		end

	end


	def createIndex( fname)
		@htmlIndexFile= @report_path+ fname
		htmlHdl=HtmlResultOutput.new( @htmlIndexFile, @confGlobFile, false, :indextab, nil) 	# setSpacer=false, not appending

		flist=Array.new
		flist.concat( Dir.glob( @report_path+'*.html'))                							# get file list and check for existence
		flist= flist-[ (@report_path+fname)]                                		            # take away itself from the list
		flist.sort_by! {|filename| File.mtime(filename) }

		flist.each do |fn|
			fileData=getFileInfo( fn)
			htmlHdl.addHtmlIndexData( fileData)
		end
		htmlHdl.closeHtmlData
	end

	def getFileInfo(filename)                                                                    # fielname i fullpath
		info= Array.new
		t= File.ctime(filename)                                                                  # get creation time
		info << t.strftime("%Y-%m-%d %H:%M:%S")
		t= File.mtime(filename)                                                                  # get creation time
		info << t.strftime("%Y-%m-%d %H:%M:%S")
		bn= File.basename( filename)                                                             # get name only
		s= bn.split(/[-]/)
		info << s[0]                                                                             # config file
		info << if s[1] then s[1] else ''  end                                                   # execution host
		l=Hash.new
		l['text']= 'Details'
		l['link']= getUrlFromFileName( filename)
		info << l
		return info
	end
end