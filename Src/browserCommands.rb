# encoding: UTF-8
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
require_relative 'windows_handles.rb'
# require 'minitest'

TIMETICK		=0.2
TIMETICKSHORT	=0.2
StartTO			=2000

class GenBrowser          < Watir::Browser

	def initialize ( )
		@status= nil
		@wwBrws= nil
		profile= $gcfd.brwsrProfile
		@brwsrType= $gcfd.brwsrType[0..1].downcase												# normalize browser types
    	@brTypeSym= nil

		if !($gcfd.testMode)														          	# not in test mode
			begin
				case @brwsrType
					when 'ie'
			            @brTypeSym= :ie
						@wwBrws= Watir::Browser.new(@brTypeSym, :native_events=>false)
					when 'ch'
						@brTypeSym= :chrome
						prefs = {
							:download => {
								:prompt_for_download => false,
								:default_directory => $gcfd.downLoadPath
							}
						}
						switches = Array.new
						proxy= $gcfd.proxy
						if(proxy)
							switches << '--proxy-server=http://'+proxy['user']+':'+proxy['passwd']+'@'+ proxy['proxyServer']
							if proxy['noProxyfor']
								switches << '--proxy-bypass-list='+proxy['noProxyfor']
							end
						else
							switches << '--no-proxy-server'
						end
						@wwBrws= Watir::Browser.new @brTypeSym, :prefs => prefs, :switches => switches
					when 'ed'
						@brTypeSym= :edge
						@wwBrws= Watir::Browser.new 'edge'
#						@wwBrws.setPreference("webdriver.load.strategy", 'eager');
					else
						type='fi'
            			@brTypeSym= :firefox
						if(profile=='')
							ffProfile = Selenium::WebDriver::Firefox::Profile.new
							ffProfile['browser.download.folderList'] = 2 						# custom location
							if Selenium::WebDriver::Platform.windows?
								ffProfile['browser.download.dir'] = $gcfd.downLoadPath.gsub("/", "\\")
							else
								ffProfile['browser.download.dir'] = $gcfd.downLoadPath
							end
							ffProfile['browser.helperApps.neverAsk.saveToDisk'] = "text/csv,application/pdf,application/txt"
							@wwBrws= Watir::Browser.new @brTypeSym, :profile => ffProfile		# Firefox or Chrome with profile
						else
							@wwBrws= Watir::Browser.new @brTypeSym, :profile => profile			# Firefox or Chrome with profile
						end
				end

				$alog.lwrite( @brTypeSym.to_s+ ' opened with profile /'+profile+'/', 'INFO')
				$gcfd.res= 'OK'
				@status= OK
			rescue
				msg= 'Cannot open browser. '+ $!.to_s
				$alog.lwrite(msg, 'ERR_')
				@status= CRITICAL
				if(@hlmode== true)
					@headless.destroy
				end
				$alog.lclose
				exit!(UNKNOWN)
			end
		end

		@screenList=Array.new
		@pageTimer= 0
		@pageTimeOut=$gcfd.pageTimeOut
		if(@brwsrType!= 'ch') && (@brwsrType!= 'ie')
			@wwBrws.driver.manage.timeouts.page_load = @pageTimeOut							# increase page timeout
		end
		@wwBrws.driver.manage.window.maximize
    	@winHandles=WinHandle.new(@wwBrws, @brTypeSym)

	end

#	attr_accessor :assertion
	attr_reader   :status, :screenList
	attr_accessor :wwBrws, :brTypeSym

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
	def retControl(res)
		return ((($gcfd.runMode==CUCUMBER) &&(res!=OK)) ? raise() : res)
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
	def returnRes( res)
		$pfd.tstop( @wwBrws.url.to_s)
		if ($gcfd.runMode==CUCUMBER) &&(res!=OK)
			raise 'Xover error '+res.to_s
		else
			return res
		end
	end

################################################################################
	def setResCritical (msg)
		$pfd.calcApplRes(false, msg, @wwBrws.url.to_s)                             # return stack trace excluding cucumber
		stack= caller.select { |s| !s.match(/cucumber/)}
		$alog.lwrite(('='*30+ "  Code Stack trace: \n"+stack.join("\n")+"\n"), 'DEBG')
		self.XOtakeScreenShot
		return CRITICAL
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
		returnRes( res)
	end

################################################################################
	def checkHTTPerr(tag, tvalue)
		if(res= self.checkCode( 404, 'not found') !=OK)						# uses $browsers global
			msg= 'HTTP_ERR: 404 not found on URL '+ $brws.url.to_s
#			@httpCode= '404'
#			@httpRes= 'Not found'
		elsif(res= self.checkCode( 500, 'server') !=OK)						# check 500
			msg= 'HTTP_ERR: 500 internal server error on URL '+ $brws.url.to_s
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
			if(@wwBrws.link(:text, tvalue).exists?)	    then found= true; end
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
		return found
	end

#XO#############################################################################
#XO
#XO 	Xover Public Methods
#XO
#XO#############################################################################
#XO	Sleep for a random time
#XO		rangeTO[0]: min time
#XO		rangeTO[1]: max time
	def XOwaitThinkTime(rangeTO)
		sleepTime= rand(rangeTO[0]..rangeTO[1])
		$alog.lwrite(('Sleeping for '+sleepTime.to_f.to_s+' s.'), 'DEBG')
		sleep(sleepTime)
		return OK
	end

#XO#############################################################################
#XO	Init screenshot
#XO 	no parameters
	def XOinitScreenShot()
		@screenList= Array.new
		$alog.lwrite('Image list cleared ', 'DEBG')
		res= OK
		return res
	end

#XO#############################################################################
#XO	Take screenshot
#XO		no parameters
	def XOtakeScreenShot()
		begin
			if(@brTypeSym== :chrome)
				width = @wwBrws.execute_script("return Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth);")
				height = @wwBrws.execute_script("return Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight);")
#
# Add some pixels on top of the calculated dimensions for good
# measure to make the scroll bars disappear
#
				@wwBrws.window.resize_to(width+100, height+100)
			end

			imgName= $gcfd.report_path+@wwBrws.url.tr(" =%?*/\\:&~",'_')[0..100]+Time.now.to_i.to_s+'.png'
			@wwBrws.screenshot.save imgName
			@screenList << imgName
			$alog.lwrite(('Image saved in '+imgName), 'DEBG')
			res= OK
		rescue
			$alog.lwrite('Problems taking screenshots: '+$!.to_s, 'ERR_')   				#
			res= CRITICAL
		end
		return res
	end

#XO#############################################################################
#XO	Save HTML page
#XO 	no parameters
 	def XOsavePage()
		begin

			fileName= $gcfd.logPath+@wwBrws.url.tr(" =%?*/\\:",'_')+Time.now.to_i.to_s+'.html'
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

#XO#############################################################################
#XO	Log a message to log file
#XO		errFlag: false if this is an error, true for just recording a message
#XO		msg: string to write
	def XOrecordAppMsg( errFlag, msg)
		$pfd.calcApplRes( errFlag, msg, @wwBrws.url.to_s)
		if !errFlag
			self.XOtakeScreenShot
		end
		returnRes (errFlag ? OK : CRITICAL)
	end

#XO#############################################################################
#XO	Perform a click on any object
#XO		tag: HTML selector type (symbol). E.g. xpath: id: name: ...
#XO		tvalue: string. Actual value for the selector
#XO	Any type of 'clickable' objects is allowed. If the obj si not present, an error is returned
#XO	  	This function does not wait: be sure the obj is laready present
	def XOclick( tag, tvalue)
		url= @wwBrws.url.to_s													# start timer in any case
		res= OK																	# default is OK
		found= false
		begin

			$pfd.tstart( url)
			if (!found && ([:xpath, :id, :css, :class, :span, :li].include? tag))
				if @wwBrws.element(tag=>tvalue).exists?
					found=true
					$alog.lwrite(('Clck on element /'+tag.to_s+'/'+tvalue+'/'), 'DEBG')	# NEW page
					@wwBrws.element(tag=> tvalue).click
				end
			end
			if (!found && ([:type, :style, :name].include? tag))
				if(@wwBrws.checkbox(tag=>tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on checkbox /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.checkbox(tag=> tvalue).set

				elsif(@wwBrws.radio(tag=>tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on Radio /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.radio(tag=> tvalue).set

				elsif(@wwBrws.button(tag=>tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on Button /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.button(tag=> tvalue).click

				elsif(@wwBrws.span(tag=>/#{tvalue}/).exists?)
					found=true
					$alog.lwrite(('Clck on span /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.span(tag=> /#{tvalue}/).click

				elsif(@wwBrws.div(tag=>/#{tvalue}/).exists?)
					found=true
					$alog.lwrite(('Clck on div /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.div(tag=> tvalue).click

				elsif(@wwBrws.li(tag=>/#{tvalue}/).exists?)
					found=true
					$alog.lwrite(('Clck on li /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.li(tag=> /#{tvalue}/).click
				end
			end
			if (!found &&  (:value==tag))
				if (@wwBrws.radio(tag=> tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on Radio /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.radio(tag=> tvalue).set
				elsif(@wwBrws.checkbox(tag=>tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on checkbox /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.checkbox(tag=> tvalue).set
				elsif(@wwBrws.button(tag=>tvalue).exists?)
					found=true
					$alog.lwrite(('Clck on Button /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.button(tag=> tvalue).click
				end
			end
			if (!found && ([:text, :link].include? tag))
				if(@wwBrws.link(tag=>/#{tvalue}/).exists?)
					found= true
					$alog.lwrite(('Clck on link /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')		# NEW page
					@wwBrws.link(tag=> /#{tvalue}/).click
				end
			end
			if (!found && ([:alt, :src].include? tag))
				if(@wwBrws.image(tag=>tvalue).exists?)
					found= true
					$alog.lwrite(('Clck on image /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					@wwBrws.image(tag=> tvalue).click
				end
			end
			if (!found)
#				CRITICAL
#				$pfd.calcApplRes(false, msg, url)
#				self.XOtakeScreenShot
				msg= 'Click on unknown obj. Selector: /'+ tag.to_s+'/ value: /'+tvalue+'/. '
				res= setResCritical (msg)
				found= false
			end
		rescue
			msg= 'Click: CANnot find obj: tag /'+ tag.to_s+'/ value /'+tvalue+'/. '+$!.to_s
			res= setResCritical (msg)
			found= false
		end

		returnRes (found ? OK : CRITICAL)
	end

#XO#############################################################################
#XO	Goto a URL
#XO 		url: string
	def XOgoto (url)
		begin
			$pfd.tstart( url)
            @wwBrws.goto( url)
			res= OK
		rescue
			msg= 'Cannot reach URL: '+url.to_s
			res= setResCritical (msg)

#			$pfd.calcApplRes(false,('Cannot reach URL. Parm: /'+url+'/'), url.to_s)
#			res= CRITICAL
#			self.XOtakeScreenShot
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Select an element from a drop down list
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO		value: string. Value in the list to be selected. Only a single value is supported
	def XOselectList(tag, tvalue, value)

		url= @wwBrws.url.to_s
		res= OK																	# default is OK

#		loc= tag.to_s+' with value:/'+tvalue+'/ and values '+values.join(',')
		loc= tag.to_s+' with value:/'+tvalue+'/ and values '+value
		$pfd.tstart( url)
		begin
			if(@wwBrws.element(tag=>tvalue).exists?)
				@wwBrws.select_list(tag=>tvalue).select(value)					# single value
				if(self.brTypeSym==:ie)
					@wwBrws.select_list(tag=>tvalue).fire_event('change')
				end
				$pfd.calcApplRes(true, 'OK: Selected list: '+loc, url)
				res=OK
			else
				res= setResCritical ('Object not found: '+loc)
			end
		rescue
			res= setResCritical ('CANnot select list '+loc+' : '+$!.to_s)
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Type a  text to any input text area
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO		text to be written
	def XOtypeText(tag, tvalue, text)
		res= OK
		begin
			$pfd.tstart( @wwBrws.url.to_s)
			self.setPageTimer()									 				# set or clear the page timer
			timedOut= false

			until ((timedOut=self.getPageTimer()) || @wwBrws.element(tag=>tvalue).exists?)
				sleep TIMETICK
			end
			if timedOut
				msg= 'CANnot find box /'+tag.to_s+'/,/'+tvalue+'/: '+$!.to_s
				res= setResCritical( msg)
			else
				if(@wwBrws.textarea(tag=>tvalue).exists?)
					t= @wwBrws.textarea(tag, tvalue)
				else
					t= @wwBrws.text_field(tag, tvalue)
				end
				t.clear
				t.set(text)
				$alog.lwrite(('Wrote /'+text+'/ to box /'+tag.to_s+'/,/'+tvalue+'/'), 'DEBG')
			end
		rescue
			msg='CANnot write /'+text+'/ to box /'+tag.to_s+'/,/'+tvalue+'/: '+$!.to_s
			res= setResCritical( msg)
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Select a Windows (in case there were many opened). Waits for the windows to open
#XO		tag: selector type (symbol). Allowed symbols:
#XO 		:index (unsigned integer): 0 is the first Windows, then 1, 2, ..
#XO			:url (string)
#XO			:title (string)
#XO		tvalue: integer/ string. Actual value for the selector
	def XOselectWindow(tag, tvalue)
		res= OK																	# default is OK
		$pfd.tstart( @wwBrws.url.to_s)
		begin
			self.setPageTimer()									 				# set or clear the page timer
			$pfd.tstart( @wwBrws.url.to_s)
			timedOut= false

            @winHandles.checkHandle (self)              						#  add/ delete any new window
			$alog.lwrite(('There are '+@wwBrws.windows.size.to_s+' active windows.'), 'DEBG')
			case tag
				when :index
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:index => tvalue).exists?)
						sleep TIMETICK
					end
					$alog.lwrite(('2nd. Found. There are '+@wwBrws.windows.size.to_s+' active windows.'), 'DEBG')
					if timedOut
						res= CRITICAL
					else
						$alog.lwrite(('3nd. Activating. There are '+@wwBrws.windows.size.to_s+' active windows.'), 'DEBG')
            			res= @winHandles.activateHandle(self, tvalue)
					end
				when :url
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:url => /#{tvalue}/).exists?)
						sleep TIMETICK
					end
					if timedOut
						res= CRITICAL
					else
						@wwBrws.window(:url => /#{tvalue}/).use
					end
				when :title
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:title => /#{tvalue}/).exists?)
						sleep TIMETICK
					end
					if timedOut
						res= CRITICAL
					else
						@wwBrws.window(:title => /#{tvalue}/).use
					end
			end
			if(res==CRITICAL)
				res= setResCritical('CANnot switch to window: /'+tvalue.to_s+'/ :'+$!.to_s)
			else
				$alog.lwrite(('Now using Windows w/title '+@wwBrws.window.title.to_s+' '), 'DEBG')
			end
		rescue
			res= setResCritical('CANnot switch to window: /'+tvalue.to_s+'/ :'+$!.to_s)   				#
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Close a Windows. Windows 0 is never closed.
#XO		tag: selector type (symbol). Allowed symbols: :
#XO 		:index (unsigned integer): 0 is the first Windows, then 1, 2, ..
#XO			:url (string)
#XO			:title (string)
#XO			:allpopup (nil): all windows except Window 0 are closed
	def XOcloseWindow(tag, tvalue)
		res= OK																	# default is OK
		begin
			self.setPageTimer()            										# set or clear the page timer
			$pfd.tstart( @wwBrws.url.to_s)
			timedOut= false

			$alog.lwrite(('There are '+@wwBrws.windows.size.to_s+' active windows.'), 'DEBG')

			case tag
				when :allpopup
					res= @winHandles.closeAllHandle( self)

				when :index
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:index => tvalue).exists?)
						sleep TIMETICK
					end
					if timedOut
						res= CRITICAL
					else
						res= @winHandles.closeHandle( self, tvalue)
					end

				when :url
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:url => /#{tvalue}/).exists?)
						sleep TIMETICK
					end
					if timedOut
						res= CRITICAL
					else
						@wwBrws.window(:url => /#{tvalue}/).close
					end
				when :title
					until ((timedOut=self.getPageTimer()) || @wwBrws.window(:title => /#{tvalue}/).exists?)
						sleep TIMETICK
					end
					if timedOut
						res= CRITICAL
					else
						@wwBrws.window(:title => /#{tvalue}/).close
					end
			end

			if(res==CRITICAL)
				res= setResCritical('CANnot close window: '+$!.to_s )
			else
				$alog.lwrite(('Now using Windows w/title '+@wwBrws.window.title.to_s+' '), 'DEBG')
			end
		rescue
			res= setResCritical('CANnot close window: '+$!.to_s )
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Get field value
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name :css :span :div...
#XO		tvalue: string. Actual value for the selector
#XO	Returns a vector:
#XO		[returnCode, fieldValue]
#XO	For radio & checkbox, a string 'ON' or 'OFF' is returned
	def XOgetFieldValue(tag, tvalue)
		res= OK																	# resturn and array: res, t
		begin
			$pfd.tstart( @wwBrws.url.to_s)
			if tag==:xpath || tag==:css
				if @wwBrws.element(tag=>tvalue).exists?
					t= @wwBrws.element(tag=>tvalue).text
					$alog.lwrite(('Text /'+t+'/ read'), 'DEBG')
				end
			elsif(@wwBrws.textarea(tag=>tvalue).exists?)
				t= @wwBrws.textarea(tag=>tvalue).value
				$alog.lwrite(('Text /'+t+'/ read from text area'), 'DEBG')

			elsif(@wwBrws.text_field(tag=>tvalue).exists?)
				t= @wwBrws.text_field(tag=>tvalue).value
				$alog.lwrite(('Text /'+t+'/ read from text box'), 'DEBG')

			elsif(@wwBrws.select_list(tag=>tvalue).exists?)
				t= @wwBrws.select_list(tag=>tvalue).selected_options[0].text                 		# take ony 1st value
				$alog.lwrite(('Text /'+t+'/ read from select list '), 'DEBG')

			elsif(@wwBrws.span(tag=>tvalue).exists?)
				t= @wwBrws.span(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from span'), 'DEBG')

			elsif @wwBrws.div(tag=>tvalue).exists?
				t= @wwBrws.div(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from div'), 'DEBG')

			elsif @wwBrws.li(tag=>tvalue).exists?
				t= @wwBrws.li(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from li'), 'DEBG')

			elsif @wwBrws.td(tag=>tvalue).exists?
				t= @wwBrws.td(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from li'), 'DEBG')

			elsif(@wwBrws.radio(tag=>tvalue).exists?)
				v= @wwBrws.radio(tag=>tvalue).set?
				t= (v==true ? 'ON' : 'OFF')
				$alog.lwrite(('Radio button is /'+t), 'DEBG')

			elsif @wwBrws.checkbox(tag=>tvalue).exists?
				v= @wwBrws.checkbox(tag=>tvalue).set?
				t= (v==true ? 'ON' : 'OFF')
				$alog.lwrite(('Radio is /'+t), 'DEBG')

			else
				msg= 'Getting value from unknown obj. Selector: /'+ tag.to_s+'/ value: /'+tvalue+'/. '
				res= setResCritical( msg)
			end
		rescue
			msg= 'CANnot select text with tag: '+tag.to_s+' : '+$!.to_s
			res= setResCritical( msg)
		end
		[returnRes( res ), t]
	end

#XO#############################################################################
#XO	Enter special char (as a symbol)
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO		special char: see http://watirwebdriver.com/sending-special-keys/ for key list
	def XOenterSpecChar(tag, tvalue, spChSym)
		begin
			$pfd.tstart( @wwBrws.url.to_s)
			res= OK																# default is OK
			@wwBrws.element(tag, tvalue).send_keys(spChSym)
			$alog.lwrite('Sent char :' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/', 'DEBG')
			res= OK
		rescue
			msg='CANnot send char' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/: '+$!.to_s
			res= setResCritical( msg)
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Drag and drop an element
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO		right_by: down_by: signed integer: offset in pixel
	def XOdragAndDrop(tag, tvalue, right_by, down_by)

		url= @wwBrws.url.to_s
		$pfd.tstart(url)
		begin
			el= @wwBrws.element(tag, tvalue)
			el.drag_and_drop_by( right_by, down_by)
			$pfd.calcApplRes(true, 'Drag and drop '+par1+' by '+right_by.to_s+'/'+down_by.to_s, url)
			sleep TIMETICK														# small sleep to let objects appear
			res= OK
		rescue
			msg='DragAndDrop failed. Values: /'+tag.to_s+'/'+tvalue+'/ '+$!.to_s
			res= setResCritical( msg)
		end
		returnRes (res )
	end

#XO#############################################################################
#XO	Unified waitfor, verifyText, verify Title etc
#XO		It logs errors/raises exception if it doesn't not find the element
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO		true if you need to wait for
#XO	If the element is not found, an CRITICAL/exception is returned
	def XOlookFor(tag, tvalue, wait)
		res= OK																	# default is OK
		url= @wwBrws.url.to_s
		$pfd.tstart( url)
		$alog.lwrite(('LookForElement '+tag.to_s+' with value /'+tvalue+'/'), 'DEBG')
		begin
			(wait  ? self.setPageTimer() : self.clearPageTimer()) 				# set or clear the page timer
			finished= false
			until (self.getPageTimer() || (finished=findElement(tag, tvalue)))
				sleep TIMETICK
			end
			if(findElement(tag, tvalue))
				$pfd.calcApplRes(true,'OK: '+tag.to_s+' found:/'+tvalue+'/', url)
				res= OK
			else
				msg= tag.to_s+' not found. Value: /'+tvalue+'/ '+$!.to_s
				res= setResCritical( msg)
			end
		rescue
			msg= tag.to_s+' not selectable. Value: /'+tvalue+'/ '+$!.to_s
			res= setResCritical( msg)
		end

		returnRes (res )
	end

#XO#############################################################################
#XO	This is the unified test function
#XO	It logs errors BUT it does NOT raises exception if it doesn't not find the element.
#XO	It can be used to check for optional elements
#XO		tag: HTML selector type (symbol). E.g. :xpath :id :name ...
#XO		tvalue: string. Actual value for the selector
#XO	It returns:
#XO		OK: found / WARN: not found
	def XOcheckFor(tag, tvalue)
		url= @wwBrws.url.to_s
		res=OK
		$alog.lwrite(('Checking element '+tag.to_s+' with value /'+tvalue+'/'), 'DEBG')
		begin
			$pfd.tstart( url)
			found= findElement(tag, tvalue)
			if(found)
				$pfd.calcApplRes(true,'Check: '+tag.to_s+' found:/'+tvalue+'/', url)
				res= OK
			else
				$pfd.calcApplRes(true, tag.to_s+' not found. Value: /'+tvalue+'/ '+$!.to_s, url)
				res= WARNING
			end
		rescue
			msg= tag.to_s+' not selectable. Value: /'+tvalue+'/ '+$!.to_s
			res= setResCritical( msg)
		end
		return res
	end

#XO#############################################################################
#XO	This is to record application errors
#XO 	msg: text message to be logged/  returned to HTML report
	def XOerror(msg)
		res= setResCritical (msg)
		returnRes( res)
	end

#XO#############################################################################
#XO	This closes properly the browser instance
#XO 	no parameters
	def XOclose
		sleep TIMETICK

		begin
			@wwBrws.close
		rescue
#			::Process.kill('KILL', browser_pid)
		end
		$alog.lwrite('Browser closed!', 'DEBG')
		return retControl(OK)
	end
end
