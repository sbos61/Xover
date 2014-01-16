################################################################################
# Performance and result routines
#   NB
# each line on data file is a CSV of:
#   timeStamp, dur, urlLabel, httpRes, null, null, null, applRes
#
################################################################################
# This makes the file compatible with .jtl from Jmeter


FILEMAXLEN	=10240

class PerfData

def initialize(fileName, testMode, runMode, testType)							# full pathname filename
	@jtlfile=''
	@jtlTotal=''
	@jtlLines=[]
	@tStarted= false
	@dataSaved= true
	@startTime= 0
	@stopTime= 0
	@testNum= 0

	@dur=0
	@urlLabel=''
	@httpRes= 'OK'																# maps to 200 response
	@httpCode= '200'
	@applRes= 'true'															# true if OK, add thread group, byte latency
	@header='timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes,latency'

#
# 1337265181351,547,index.php,200,OK,Thread 1-1,text,true,7020,547
#
	@applResMsg= ''																# final msg to print
	@globalRes='OK'
	@retState= OK																# string with status
																				# integer with return code
	index =  fileName.rindex('.')												# take log file full name
	if(index)
		jtlname= fileName[0 , index]											# strip off extension
	else
		jtlname= fileName														# if there is no extension, take the full name
	end
	@jtlfile= jtlname+ '.jtl'													# calculate jtl file full name
	@jtlTotal= jtlname+ '-tot.jtl'												# calculate jtl total test full name

	unless testMode 															# if not in test mode
		@fHdl = File.new(@jtlfile, 'w') 											# if exists, it will be overwritten
		@fHdl.puts @header
		if ((runMode==STANDALONE)||(runMode==CUCUMBER)) 						# ONLY in STANDALONE mode,
			if File.exists?(@jtlTotal)
				@fhTot = File.new(@jtlTotal, 'a') 								# append at the end
				@fhTot.close
			else
				@fhTot = File.new(@jtlTotal, 'w') 								# it does not exists, if exists, it will be overwritten
				@fhTot.puts @header
				@fhTot.close
			end
			if @fhTot then
				$alog.lwrite(('Jtl file '+@jtlTotal+' opened'), 'DEBG')
			else
				@retState= UNKNOWN
				@applResMsg= 'Cannot open file '+@jtlTotal 						# overwrite prev messages
				$alog.lwrite(@applResMsg, 'ERR_')
			end
		end
		if @fHdl then
			$alog.lwrite(('Jtl file '+@jtlfile+' opened'), 'DEBG')
		else
			@retState= UNKNOWN
			@applResMsg= 'Cannot open file '+@jtlfile 							# overwrite prev messages
			$alog.lwrite(@applResMsg, 'ERR_')
		end
		if testType==JMETER
			@fHdl.close
			@fHdl=nil
		end
	end
	return @retState
end

attr_accessor :applResMsg, :retState, :globalRes, :testNum
attr_reader :jtlfile

################################################################################
#
# save perf data on jtl file
#
# timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes
	def savePerfLine
		line= @startTime.to_i.to_s+','+@dur.to_s+','+@urlLabel+','+@httpCode+','+@httpRes+',Test_'+@testNum.to_s+',text,'+@applRes+',1,1'
		@fHdl.puts line
		@dataSaved = true

	end

################################################################################
#
# generic error management from browser
# some attempt is done to detect the error type
#
	def calcApplRes( flag, msg, url)												# true if NO error detected
		res=OK
		if flag
			$alog.lwrite(msg, 'DEBG')
		else
			$alog.lwrite( msg, 'ERR_')
			res= self.setApplErr( msg)
		end
		if @tStarted
			self.tstop(url)
		end
		return res
	end

	def setApplErr( msg)														# error detected
		@applResMsg+=msg+ "\n"
		@applRes='false'


		return CRITICAL
	end

################################################################################
	def tstart(url)																# Start misuring time.
																				# If there is something to save, do it
		if(@tStarted == true)
			$alog.lwrite(('Timer double started'), 'DEBG')
			self.tstop( url)
		end

		if(@dataSaved == false)
			savePerfLine															# write perfomance data line to file
		end

		@applRes= 'true'
		@httpRes= 'OK'																# maps to 200 response
		@httpCode= '200'

		@dataSaved = true
		@stopTime= 0
		@dur=0
		@urlLabel=url.tr(',','-')													# needed to support csv format
		@tStarted= true
		@startTime= Time.now.to_f* 1000

	end

################################################################################
	def tstop(url)																	# stop timer, save to file

		if(@tStarted == false)
			$alog.lwrite( 'Timer stopped but not started: URL '+ url, 'DEBG')
		else
			$alog.lwrite('Appl. Timer stopped on URL: '+ url+'. ', 'DEBG')
			@stopTime= Time.now.to_f* 1000
			@dur=( @stopTime- @startTime).to_i
			@tStarted= false
			@dataSaved = false
		end																			# check for HTTP errors
	end

################################################################################
#
# Append data to jtl file
#
	def append2JtlTotal
	@fHdl = File.new( @jtlfile, 'r')												# open single service file
	@fHdl.gets																	# skip first line
	@fhTot = File.new( @jtlTotal, 'a')											# append at the end
	@fhTot.puts @fHdl.gets(nil, FILEMAXLEN)
	@fHdl.close
	@fhTot.close
end

################################################################################
#
# Check against each TX thresholds
#
	def checkThreshold(pfData, stxd, nameTX, durTX)

	if(stxd.nTX> 0)																# check theresholds
		(0..stxd.nTX-1).each do |i|
			nmTX= stxd.GetTxName(i)
			cleanNmTX= nmTX.tr(' =%?*','_')										# clean up string
			if nameTX.include? nmTX
				if(durTX> stxd.GetCritTO(i))
					msg= 'TXTO_ERR on ''+ nmTX+'': '+ sprintf('%.3f',durTX)+'s. TOcrit '+stxd.GetCritTO(i).to_s
					$alog.lwrite(msg, 'ERR_')
					if(@retState<CRITICAL)
						@retState= CRITICAL
						self.setApplErr( msg)
					end
				elsif(durTX> stxd.GetWarnTO(i))
					msg= 'TXTO_WRN on ''+ nmTX+'': '+ sprintf('%.3f',durTX)+'s. TOwarn '+stxd.GetWarnTO(i).to_s
					$alog.lwrite(msg, 'WARN')
					if(@retState<WARNING)
						@retState= WARNING
						self.setApplErr( msg)
					end
				else
					msg= 'TXPASS__ on ' +nmTX +'. Time: '+ sprintf('%.3f',durTX)
					$alog.lwrite(msg,'DEBG')										# state unchanged
				end
				pfData= pfData+ cleanNmTX+ '='+sprintf("%.3f",durTX)+'s;'+stxd.GetWarnTO(i).to_s+';'+stxd.GetCritTO(i).to_s+';0 ' #

				return pfData													# return when 1st match found
			end			
		end
	end
	return pfData
end

################################################################################
#
# Calculate Perf data string from data
# Time are returned in seconds
#
	def CalcPerfData( iServ, warnTO, critTO)

	totTime= 0.0
	httpRes='OK'
	applRes='OK'
	perfData=''
	failure= ''
#   state= 'OK'

	begin
		@fHdl = File.new( @jtlfile, 'r')											# read jtl file and do sums
		@fHdl.gets																# skip first line with headers
	rescue
		@retState = UNKNOWN
		@applResMsg= 'UNKN_ERR Cannot open '+@jtlfile       					# overwrite prev messages
		return @retState														# Cannot read file: fatal error
	end

	parms= Array.new
	@fHdl.each_line do |fline|
		parms= fline.split(/[\,,\n]/)

#	@header='timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes'
# 				0			1	2			3			4				5		6		7		8
		timeTX= parms[1].to_f/1000
		lblTX=  parms[2]
		httpTX= parms[4]
		applTX= parms[7]														# start from end: url may contains ','

		totTime+= timeTX														# sums
		if !(httpTX.include? 'OK')												# error @http level
			msg= 'HTTP_ERR on '+ lblTX+'. '+ timeTX.to_s
			$alog.lwrite(msg, 'ERR_')
			if @retState <CRITICAL 												# in case of multiple errors, returns the first
				self.setApplErr( msg)
				@retState= CRITICAL
			end
		elsif(!applTX.include? 'true')											# error @applications level
			msg= 'APPL_ERR on '+ lblTX+'. '+ timeTX.to_s
			$alog.lwrite(msg, 'ERR_')
			if(@retState <CRITICAL)
				self.setApplErr( msg)
				@retState= CRITICAL
			end
		end																		# if no error, leave prev msg

		perfData= checkThreshold(perfData, $gcfd.scfd[iServ].sTxData, lblTX, timeTX) # match against single TX info
	end

#   Error Hierarchy: FIRST error is the one reported
#   1- HTTP error
#   2- application error
#   3- single TX critical TO
#   4- global critical TO

	if(totTime<=0)																# start evaluation fo total time against global thresholds
		@retState = UNKNOWN
		@applResMsg= 'UNKN_ERR Invalid total time'								# overwrite prev messages
		$alog.lwrite(@applResMsg, 'ERR_')
	end
	if(@retState == UNKNOWN)													# final processing (global thrsh. TO etc)
		if(@applResMsg=='')
			@applResMsg= 'UNKN_ERR Time: '+sprintf("%.3f",totTime)+'s'			# overwrite prev messages
		end
		$alog.lwrite(@applResMsg, 'ERR_')
	elsif(@retState == CRITICAL)
#		@applResMsg+= ' Time: '+sprintf("%.3f",totTime)+'s '
		$alog.lwrite(@applResMsg, 'ERR_')
	elsif(@retState == WARNING)
		if totTime > critTO
			@retState = CRITICAL
			msg= 'TIME_ERR Time '+ sprintf("%.3f", totTime)+ ' s(critical '+sprintf("%.3f",critTO)+' s)'
			self.setApplErr( msg)
			$alog.lwrite(msg, 'ERR_')
		else
			$alog.lwrite(@applResMsg, 'WARN')
		end
	else																		# if status is still OK
		if(totTime > critTO)
			@retState = CRITICAL
			msg= 'TIME_ERR Time '+sprintf("%.3f",totTime)+' s (critical '+sprintf("%.3f",critTO)+' s)'
			self.setApplErr( msg)
			$alog.lwrite(msg, 'ERR_')
		elsif(totTime > warnTO)
			@retState = WARNING
			msg= 'TIME_WRN Time '+sprintf("%.3f",totTime)+' s (warning '+sprintf("%.3f",warnTO)+' s)'
			self.setApplErr( msg)
			$alog.lwrite(msg, 'WARN')
		else
			if @applResMsg==''
				@applResMsg= 'PASSED__ Time '+sprintf("%.3f",totTime)				# last and final
			end
			calcApplRes( true, @applResMsg, '')
			@retState = OK
		end
	end

	@fHdl.close																	# close perf file
	perfData= @applResMsg+ ' | time='+sprintf("%.3f",totTime)+'s;'+warnTO.to_s+';'+critTO.to_s+';0 '+perfData;
	$alog.lwrite(perfData, 'DEBG')
	return perfData

end

################################################################################
#
#
#
	def perfClose(service, lastUrl)

	if(@fHdl!=nil)
		if(@fHdl)																# non opened in test mode
			if(@tStarted == true)
				self.tstop( lastUrl)
			end
			if(@dataSaved == false)
				savePerfLine													# write perfomance data line to file
			end
			@fHdl.close
		end
		$alog.lwrite('Perf Data file closed: starting analysis' , 'INFO')
	else
		$alog.lwrite('Perf Data file found closed: starting analysis' , 'INFO')
	end
end

end

