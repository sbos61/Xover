################################################################################
#
#		browser Windows management by Handle (required by Internet Explorer )
#
class WinHandle
	def initialize(wwbrws, brTypeSym)
	@winHandles=Array.new
	case brTypeSym
	  when :ie
		@winHandles[0]= wwbrws.driver.window_handles[0]
	  when :chrome, :firefox
		@winHandles[0]= 0
	end

  end

	def checkHandle( b)
		case b.brTypeSym
			when :ie
				newH= b.wwBrws.driver.window_handles
				if(newH.size> @winHandles.size)         # new window
		  			lastH= newH- @winHandles
					@winHandles<< lastH[0]
				elsif(@winHandles.size > newH.size)      # window has been deleted
					oldH= @winHandles- newH
					@winHandles -=oldH
				end
			else
				nWin=b.wwBrws.windows.size
				nWin.times do | iWin|
					@winHandles[iWin]= iWin
				end
		end
	return OK
	end

  	def getTopHandle( b)
		self.checkHandle( b)
		case b.brTypeSym
			when :ie
				self.checkHandle( b)
				lastH= @winHandles.size-1
				b.wwBrws.driver.switch_to.window( @winHandles[lastH])
			else
				lastH= @winHandles.size
				b.wwBrws.window( :index => lastH).use
		end
		return OK
  end

	def activateHandle( b, h)
#		$alog.lwrite(('4nd. Activating handle'+h.to_s), 'DEBG')
		self.checkHandle( b)
		case b.brTypeSym
			when :ie
				b.wwBrws.driver.switch_to.window( @winHandles[h] )
			when :chrome, :firefox
				b.wwBrws.window(:index => h).use
		end
		return OK
	end

	def closeHandle( b, h)
		self.checkHandle( b)
		case b.brTypeSym
			when :ie
				b.wwBrws.driver.switch_to.window( @winHandles[h] )
				b.wwBrws.window.close
				@winHandles.delete_at( h)
				lastH= @winHandles.size
				b.wwBrws.driver.switch_to.window( @winHandles[lastH-1] )
			when :chrome, :firefox
				b.wwBrws.window(:index => h).close
		end
		self.checkHandle( b)
		return res
	end

	def closeAllHandle( b)
#	lastH= @winHandles.size
		self.checkHandle( b)
		case b.brTypeSym
			when :ie
				newH= b.wwBrws.driver.window_handles
				lastH= newH.size-1
				if(0==lastH)
					res= OK
				else
					1.upto( lastH) do |iHandle|
						b.wwBrws.driver.switch_to.window( @winHandles[iHandle] )
						b.wwBrws.window.close
						@winHandles.delete_at( iHandle)
					end
				end
				b.wwBrws.driver.switch_to.window( @winHandles[0] )
				res=OK
			else
				newH=b.wwBrws.windows
				lastH= newH.size-1
				if(0==lastH)
					res=OK
				else
					1.upto( lastH) do |iHandle|
						b.wwBrws.window(:index => iHandle).close
					end
				end
				b.wwBrws.window(:index, 0).use
				res=OK
		end
		self.checkHandle( b)
		return res
	end

end
