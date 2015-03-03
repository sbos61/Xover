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
		@brwsrType= $gcfd.brwsrType[0..1].downcase								# normalize browser types
    @brTypeSym= nil

		if !($gcfd.testMode)														          # not in test mode
#			begin Timeout::timeout( StartTO) do
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
						@wwBrws= Watir::Browser.new @brTypeSym, :prefs => prefs
					else
						type='fi'
            @brTypeSym= :firefox
						if(profile=='')
							ffProfile = Selenium::WebDriver::Firefox::Profile.new
							ffProfile['browser.download.folderList'] = 2 # custom location
							if Selenium::WebDriver::Platform.windows?
								ffProfile['browser.download.dir'] = $gcfd.downLoadPath.gsub("/", "\\")
							else
								ffProfile['browser.download.dir'] = $gcfd.downLoadPath
							end
							ffProfile['browser.helperApps.neverAsk.saveToDisk'] = "text/csv,application/pdf,application/txt"
							@wwBrws= Watir::Browser.new @brTypeSym, :profile => ffProfile		# Firefox or Chrome with profile
						else
							@wwBrws= Watir::Browser.new @brTypeSym, :profile => profile		# Firefox or Chrome with profile
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

		@pageTimer= 0
		@pageTimeOut=$gcfd.pageTimeOut
		if(@brwsrType!= 'ch') && (@brwsrType!= 'ie')
			@wwBrws.driver.manage.timeouts.page_load = @pageTimeOut							# increase page timeout
		end
		@wwBrws.driver.manage.window.maximize
    @winHandles=WinHandle.new(@wwBrws, @brTypeSym)

	end

#	attr_accessor :assertion
	attr_reader   :status
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
		if ($gcfd.runMode==CUCUMBER) &&(res!=OK)
			raise
		else
			return res
		end
	end

################################################################################
	def setResCritical (msg)
		$pfd.calcApplRes(false, msg, @wwBrws.url.to_s)
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
			if(@wwBrws.link(:text, tvalue).c)	    then found= true; end
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
			imgName= $gcfd.logPath+@wwBrws.url.tr(" =%?*/\\:",'_')+Time.now.to_i.to_s+'.png'
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

################################################################################
	def XOrecordAppMsg( errFlag, msg)                                             # flag is false if it is an error
		$pfd.calcApplRes( errFlag, msg, @wwBrws.url.to_s)
		if !errFlag
			self.XOtakeScreenShot
		end
		returnRes (errFlag ? OK : CRITICAL)
	end

################################################################################
	def XOclick( tag, tvalue)
		url= @wwBrws.url.to_s													# start timer in any case
		res= OK																	# default is OK
		found= false
		begin

			if (!found && ([:xpath, :id, :css, :class, :span, :li].include? tag))
				if @wwBrws.element(tag=>tvalue).exists?
					found=true
					$alog.lwrite(('Clck on element /'+tag.to_s+'/'+tvalue+'/'), 'DEBG')	# NEW page
					$pfd.tstart( url)
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
					$pfd.tstart( url)
					@wwBrws.div(tag=> tvalue).click

				elsif(@wwBrws.li(tag=>/#{tvalue}/).exists?)
					found=true
					$alog.lwrite(('Clck on li /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					$pfd.tstart( url)
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
					$pfd.tstart( url)
					@wwBrws.link(tag=> /#{tvalue}/).click
				end
			end
			if (!found && ([:alt, :src].include? tag))
				if(@wwBrws.image(tag=>tvalue).exists?)
					found= true
					$alog.lwrite(('Clck on image /:'+tag.to_s+'/'+tvalue+'/'), 'DEBG')
					$pfd.tstart( url)                                                      		# NEW page
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

################################################################################
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

################################################################################
	def XOselectList(tag, tvalue, value)                                     	# vale solo per oggetti singoli

		url= @wwBrws.url.to_s
		res= OK																	# default is OK

#		loc= tag.to_s+' with value:/'+tvalue+'/ and values '+values.join(',')
		loc= tag.to_s+' with value:/'+tvalue+'/ and values '+value
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

################################################################################
	def XOtypeText(tag, tvalue, text)
		res= OK
		begin
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
				$alog.lwrite(('Wrote /'+text+'/ to box /'+tag.to_s+'/,/'+tvalue), 'DEBG')
			end
		rescue
			msg='CANnot write /'+text+'/ to box '+tag.to_s+','+tvalue+': '+$!.to_s
			res= setResCritical( msg)
		end
		returnRes (res )
	end

################################################################################
	def XOselectWindow(tag, tvalue)												# index, url, title allowed, implicit wait
		res= OK																	# default is OK
		begin
			self.setPageTimer()									 				# set or clear the page timer
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

################################################################################
	def XOcloseWindow(tag, tvalue)												# allpopup index, url, title allowed
		res= OK																	# default is OK
		begin
			self.setPageTimer()									 				# set or clear the page timer
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

################################################################################
	def XOgetFieldValue(tag, tvalue)											# css, span, div, xpath, id allowed
		res= OK																	# resturn and array: res, t
		begin
			if tag==:xpath || tag==:css
				if @wwBrws.element(tag=>tvalue).exists?
					t= @wwBrws.element(tag=>tvalue).text
					$alog.lwrite(('Text /'+t+'/ read'), 'DEBG')
				end
			elsif @wwBrws.textarea(tag=>tvalue).exists?
				t= @wwBrws.textarea(tag=>tvalue).value
				$alog.lwrite(('Text /'+t+'/ read from text area'), 'DEBG')

			elsif @wwBrws.text_field(tag=>tvalue).exists?
				t= @wwBrws.text_field(tag=>tvalue).value
				$alog.lwrite(('Text /'+t+'/ read from text box'), 'DEBG')

			elsif(@wwBrws.span(tag=>tvalue).exists?)
				t= @wwBrws.span(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from span'), 'DEBG')

			elsif(@wwBrws.div(tag=>tvalue).exists?)
				t= @wwBrws.div(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from div'), 'DEBG')

			elsif(@wwBrws.li(tag=>tvalue).exists?)
				t= @wwBrws.li(tag=>tvalue).text
				$alog.lwrite(('Text /'+t+'/ read from li'), 'DEBG')

			else
				msg= 'Click on unknown obj. Selector: /'+ tag.to_s+'/ value: /'+tvalue+'/. '
				res= setResCritical( msg)
			end
		rescue
			msg= 'CANnot select text with tag: '+tag.to_s+' : '+$!.to_s
			res= setResCritical( msg)
		end
		[returnRes( res ), t]
	end

################################################################################
	def XOenterSpecChar(tag, tvalue, spChSym)
		begin
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
			msg='DragAndDrop failed. Values: /'+tag.to_s+'/'+tvalue+'/ '+$!.to_s
			res= setResCritical( msg)
		end
		returnRes (res )
	end

################################################################################
# This is unified waitfor , verifyText, verify Title etc
# 	It logs errors/raises exception if it doesn't not find the element
#
	def XOlookFor(tag, tvalue, wait)
		res= OK																	# default is OK
		url= @wwBrws.url.to_s
		$alog.lwrite(('WaitForElement '+tag.to_s+' with value /'+tvalue+'/'), 'DEBG')
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
#		if($gcfd.runMode==CUCUMBER) &&(res!=OK)
#			raise
#		else
#			return res
#		end
#
#		return ((($gcfd.runMode==CUCUMBER) &&(res!=OK)) ? raise() : res)
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
			msg= tag.to_s+' not selectable. Value: /'+tvalue+'/ '+$!.to_s
			res= setResCritical( msg)
		end
		return res
	end

################################################################################
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
