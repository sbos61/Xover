################################################################################
#
#	Ruby WebDriver plugin.
#	Watir single commands functions
#
################################################################################
# 
# Abstract the browser object. Uses $pfd objects
#
require 'watir-webdriver'														#open a browser WD mode
require 'watir-webdriver-performance'

TIMETICK		=0.2
TIMETICKSHORT	=0.2
StartTO			=20

class GenBrowser

	def initialize (type, profile, runMode, pageTimeOut, dataPath, clearCookie)
		@status= nil
		@wwBrws= nil
		@runMode= runMode
		@dataPath= dataPath

		begin Timeout::timeout( StartTO) do

			case type    															#here goes the browser specific ommands
				when 'ie'
					brtype= :ie
					@wwBrws= Watir::Browser.new brtype
					if clearCookie then			@wwBrws.driver.manage.delete_all_cookies	end
				when 'ch'
					brtype= :chrome
					prefs = {
						:download => {
							:prompt_for_download => false,
						},
						:intl => {
							:accept_languages => 'en-US'
						}
					}
					switches= %w[ --parent-profile f:/user/data --ignore-certificate-errors --disable-popup-blocking --disable-translate]
					@wwBrws = Watir::Browser.new :chrome, :prefs => prefs,  :switches =>  switches
					if clearCookie then			@wwBrws.cookies.clear	end
				else
					brtype= :firefox
					if profile ==''
						@wwBrws= Watir::Browser.new brtype
					else
						@wwBrws= Watir::Browser.new brtype, :profile => profile		# Firefox or Chrome with profile
					end
					if clearCookie then			@wwBrws.cookies.clear	end
			end

			$alog.lwrite( brtype.to_s+ ' opened with profile /'+profile+'/', 'INFO')
			end
			@status= OK
		rescue
			msg= 'Cannot open browser. '+ $!.to_s
			$alog.lwrite(msg, 'ERR_')
			@status= CRITICAL
		end
		@pageTimer= 0
		@pageTimeOut=pageTimeOut
		if(type!= 'ch')
			@wwBrws.driver.manage.timeouts.page_load = @pageTimeOut							# increase page timeout
		end
	end

#	attr_accessor :assertion
	attr_reader   :status

################################################################################
#
# 	Internal only methods
#
################################################################################
# 	Timeout management

	def setPageTimer
		@pageTimer= Time.now.to_i+ @pageTimeOut
		return OK
	end
	def clearPageTimer
		@pageTimer= Time.now.to_i-1												# the timer is FALSE for sure
		return OK
	end
	def getPageTimer
		return(@pageTimer <Time.now.to_i)										# TRUE if finished, FALSE if not
		return OK
	end

	def url
		@wwBrws.url.to_s
	end

################################################################################
	def checkCode( code, msg)
		if(@wwBrws.text.include? code.to_s) ||(@wwBrws.text.downcase.include? msg)	# check 404
			res= code
		elsif(@wwBrws.title.include? code.to_s) ||(@wwBrws.title.downcase.include? msg)	# check 404
			res= code
		else
			res= OK
		end
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( msg) : res)
	end

################################################################################
	def checkHTTPerr(tag, tvalue)
		if(res= self.checkCode( 404, 'not found') !=OK)						# uses $browsers global
			msg= 'HTTP_ERR: 404 not found on URL '+ @wwBrws.url.to_s
#			@httpCode= '404'
#			@httpRes= 'Not found'
		elsif(res= self.checkCode( 500, 'server') !=OK)						# check 500
			msg= 'HTTP_ERR: 500 internal server error on URL '+ @wwBrws.url.to_s
#			@httpCode= '500'
#			@httpRes= 'Internal server error'
		end
		return [res, msg]
	end

################################################################################
	def findElement(tag, tvalue)
		found= false
		case tag
		when :title
			if(@wwBrws.title.include? tvalue)			then found= true; end
		when :text
			if(@wwBrws.text.include? tvalue)			then found= true; end
		when :link
			if(@wwBrws.link(:text, tvalue).exists?)	then found= true; end
		when :span, :css, :id, :element, :type, :value, :style, :class
			if(@wwBrws.element(tag, tvalue).exists?)	then found= true; end
		when :name
			if(@wwBrws.radio(tag, tvalue).exists?)
				found= true;
			elsif(@wwBrws.button(:name, tvalue).exists?)
				found= true;
			elsif(@wwBrws.select_list(:name, tvalue).exists?)
				found= true;
			elsif(@wwBrws.element(tag, tvalue).exists?)
				found= true;
			else
#				$pfd.calcApplRes(false,'CANnot find :name with value '+tvalue, url)
				found= false
			end
		else
			$pfd.calcApplRes(false,'CANnot find selector /'+tag.to_s+'/ with value /'+tvalue+'/', url)
			found= false
		end
		return found;
	end

################################################################################
#
# 	Public methods
#
################################################################################

	def XOwaitThinkTime(rangeTO)
		sleepTime= rand(rangeTO[0]..rangeTO[1])
		$alog.lwrite(('Sleeping for '+sleepTime.to_f.to_s+' s.'), 'DEBG')
		sleep(sleepTime)
		return OK
	end


################################################################################
	def XOtakeScreenShot()
		begin
			imgName= @dataPath+@wwBrws.url.tr(" =%?*/\\:",'_')+Time.now.to_i.to_s+'.png'
			@wwBrws.screenshot.save imgName
			$alog.lwrite(('Image saved in '+imgName), 'DEBG')
			res= OK
		rescue
			$alog.lwrite('Problems taking screenshots', 'ERR_')   				#
			res= CRITICAL
		end
		return res
	end

################################################################################
	def XOsavePage()
		begin

			fileName= @dataPath+@wwBrws.url.tr(" =%?*/\\:",'_')+Time.now.to_i.to_s+'.html'
			File.open(fileName, 'w') do |file|
				file.write(@wwBrws.html)
			end
			$alog.lwrite('HTML page  saved in '+ fileName, 'DEBG')
			res= OK
		rescue
			$alog.lwrite('Problems saving page '+ fileName, 'ERR_')   			#
			res= CRITICAL
		end
		return res
	end

################################################################################
	def XOrecordAppMsg( errFlag, msg)                                             # flag is false if it is an error
		$pfd.calcApplRes( errFlag, msg, @wwBrws.url.to_s)
		return (errFlag ? OK : CRITICAL)
	end

################################################################################
	def XOclick( selector, tvalue)
		url= @wwBrws.url.to_s														# start timer in any case
		res= OK																	# default is OK
		if(selector== :link)
			selector=:text
		end

		begin
			if selector==:xpath || selector==:css
				if @wwBrws.element(selector=>tvalue).exists?
					$alog.lwrite(('Clck on element /'+selector.to_s+'/'+tvalue+'/'), 'DEBG')	# NEW page
					$pfd.tstart( url)
					@wwBrws.element(selector=> tvalue).click
				end
#			elsif @wwBrws.input(selector=>tvalue).exists?
#				$alog.lwrite(('Clck on button /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')	# NEW page
#				$pfd.tstart( url)
#				@wwBrws.input(selector=> tvalue).click

			elsif(@wwBrws.checkbox(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on checkbox /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')
				@wwBrws.checkbox(selector=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif(@wwBrws.radio(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on Radio /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')
				@wwBrws.radio(selector=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif @wwBrws.button(selector=>tvalue).exists?
				$alog.lwrite(('Clck on button /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')	# NEW page
				$pfd.tstart( url)
				@wwBrws.button(selector=> tvalue).click

			elsif(@wwBrws.link(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on link /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')		# NEW page
				$pfd.tstart( url)
				@wwBrws.link(selector=> tvalue).click

			elsif(@wwBrws.image(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on image /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')
				$pfd.tstart( url)                                                      		# NEW page
				@wwBrws.image(selector=> tvalue).click

			elsif(@wwBrws.span(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on span /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')
				$pfd.tstart( url)                                                      		# NEW page
				@wwBrws.span(selector=> tvalue).click

			elsif(@wwBrws.div(selector=>tvalue).exists?)
				$alog.lwrite(('Clck on div /:'+selector.to_s+'/'+tvalue+'/'), 'DEBG')
				$pfd.tstart( url)
				@wwBrws.div(selector=> tvalue).click

			else

				errMsg= 'Click on unknown obj. Selector: /'+ selector.to_s+'/ value: /'+tvalue+'/. '
				$pfd.calcApplRes(false, errMsg, url)
				res= CRITICAL
				self.XOtakeScreenShot
			end
		rescue
			errMsg= 'Click: CANnot find obj: tag /'+ selector.to_s+'/ value /'+tvalue+'/'+$!.to_s
			$pfd.calcApplRes(false, errMsg, url)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		$pfd.tstop( url)
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( msg) : res)
	end

################################################################################
	def XOgoto (url)
		begin
			$pfd.tstart( url)
            @wwBrws.goto( url)
			res= OK
		rescue
			errMsg= 'Cannot reach URL. Parm: /'+url+'/'
			$pfd.calcApplRes(false, errMsg, url)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		$pfd.tstop( url)
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( msg) : res)
	end

################################################################################
	def XOselectList(selector, tvalue, value)                                     # vale solo per oggetti singoli

		url= @wwBrws.url.to_s
#		loc= selector.to_s+' with value:/'+tvalue+'/ and values '+values.join(',')
		loc= selector.to_s+' with value:/'+tvalue+'/ and values '+value
		begin
			@wwBrws.select_list(selector=>tvalue).select(value)						# single value
			$pfd.calcApplRes(true, 'OK: Selected list: '+loc, url)
			res=OK
		rescue
			errMsg= 'CANnot select list '+loc+' : '+$!.to_s
			$pfd.calcApplRes(false, errMsg, url)
			res=CRITICAL
			self.XOtakeScreenShot
		end
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
	def XOtypeText(selector, tvalue, text)
		begin

			if @wwBrws.text_field(selector, tvalue).exist?
				@wwBrws.text_field(selector, tvalue).clear
				@wwBrws.text_field(selector, tvalue).set(text)
				$alog.lwrite(('Wrote /'+text+'/ to box '+selector.to_s+','+tvalue), 'DEBG')
				sleep TIMETICK														# small sleep to let objects appear
				res= OK
			else
				errMsg= 'CANnot find box '+selector.to_s+','+tvalue+': '+$!.to_s
				$pfd.calcApplRes(false, errMsg, @wwBrws.url.to_s)
				res= CRITICAL
				self.XOtakeScreenShot
			end
		rescue
			errMsg= 'CANnot write /'+text+'/ to box '+selector.to_s+','+tvalue+': '+$!.to_s
			$pfd.calcApplRes(false, errMsg, @wwBrws.url.to_s)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
	def XOenterSpecChar(tag, tvalue, spChSym)
		begin
			@wwBrws.text_field(tag, tvalue).send_keys(spChSym)
			$alog.lwrite('Sent char :' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/', 'DEBG')
			res= OK
		rescue
			errMsg= 'CANnot send char' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/'
			$pfd.calcApplRes(false, errMsg, @wwBrws.url.to_s)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
	def XOdragAndDrop(tag, tvalue, from, to)

		url= @wwBrws.url.to_s
		begin
			el= @wwBrws.element(tag, tvalue)
			$pfd.tstart(url)
			el.drag_and_drop_by( from, to)
			$pfd.calcApplRes(true, 'Drag and drop '+par1+' by '+par2, url)
			sleep TIMETICK														# small sleep to let objects appear
			res= OK
		rescue
			errMsg= 'DragAndDrop failed. Values: /'+tag.to_s+'/'+tvalue+'/ '+$!.to_s
			$pfd.calcApplRes(false, errMsg, url)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		$pfd.tstop( url)
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
# This is unified waitfor , verifyText, verify Title etc
# 	It logs errors/raises exception if it doesn't not find the element
#
	def XOlookFor(tag, tvalue, wait)

		url= @wwBrws.url.to_s
		$alog.lwrite(('WaitForElement '+tag.to_s+' with value /'+tvalue+'/'), 'DEBG')
		res= OK
		begin
			(wait  ? self.setPageTimer() : self.clearPageTimer()) 				# set or clear the page timer
			finished= false
			until (self.getPageTimer() || (finished=findElement(tag, tvalue)))
				sleep TIMETICK
			end
			if(finished)
				$pfd.calcApplRes(true,'OK: '+tag.to_s+' found:/'+tvalue+'/', url)
				res= OK
			else
				errMsg= tag.to_s+' not found. Value: /'+tvalue+'/ '+$!.to_s
				$pfd.calcApplRes(false, errMsg, url)
				res= CRITICAL
			end
		rescue
			errMsg=  tag.to_s+' not selectable. Value: /'+tvalue+'/ '+$!.to_s
			$pfd.calcApplRes(false, errMsg, url)
			res= CRITICAL
			self.XOtakeScreenShot
		end
		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
# This is unified test function
# 	It logs errors BUT it does NOT raises exception if it doesn't not find the element
#	It returns:
#      OK: found
#      WARN: not found
	def XOcheckFor(tag, tvalue)
		url= @wwBrws.url.to_s
		res=OK
		$alog.lwrite(('Checking element '+tag.to_s+' with value /'+tvalue+'/'), 'DEBG')
		begin
			found= findElement(tag, tvalue)
			if(found)
				$pfd.calcApplRes(true,'Check: '+tag.to_s+' found:/'+tvalue+'/', url)
				res= OK
			else
				$pfd.calcApplRes(true, tag.to_s+' not found. Value: /'+tvalue+'/ '+$!.to_s, url)
				res= WARNING
			end
		rescue
			$pfd.calcApplRes(true, tag.to_s+' not selectable. Value: /'+tvalue+'/ '+$!.to_s, url)
			res= WARNING
			self.XOtakeScreenShot
		end
		return res
	end

################################################################################
	def XOclose
		sleep TIMETICK

#		browser_pid = @wwBrws.driver.instance_variable_get(:@bridge).instance_variable_get(:@service).instance_variable_get(:@process).pid
#xx\		$pfd.calcApplRes(true,'Starting Browser shutdown: pid'+browser_pid.to_s, '')
		begin
			lastUrl= self.url
			@wwBrws.close
			res= OK
			$alog.lwrite('Browser closed!', 'DEBG')
		rescue
			errMsg= 'Error closing the browser: '+$!.to_s
			$pfd.calcApplRes(false, errMsg, lastUrl)
			res= CRITICAL
#			::Process.kill('KILL', browser_pid)
		end

		return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise( errMsg) : res)
	end

################################################################################
#def radioSet( tag, tvalue)
#	begin
#		@wwBrws.radio(tag, tvalue).set
#		$alog.lwrite(('Radio button '+tag.to_s+' set with value='+tvalue+'.'), 'DEBG')
#		res= OK
#	rescue
#		$pfd.calcApplRes(false, 'Radio Button '+tag.to_s+' not selectable. Value: '+tvalue+' '+$!.to_s, @wwBrws.url.to_s)
#		res= CRITICAL
#		self.XOtakeScreenShot
#	end
#	return (((@runMode==CUCUMBER) &&(res!=OK)) ? raise() : res)
#end


end
