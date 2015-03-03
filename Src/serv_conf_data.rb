
class ServTxData
	def initialize
		@nTX= 0
		@txName= Array.new														#
		@txCritTO= Array.new													# all values in s
		@txWarnTO= Array.new													# all values in s
	end

	attr_accessor :nTX
#   attr_accessor :txName, :txCritTO, :txWarnTO

	def GetCritTO(i)
		return @txCritTO[i]
	end

	def txCritTOAdd( s)
		@txCritTO.push( s)
	end

	def GetWarnTO(i)
		return @txWarnTO[i]
	end

	def txWarnTOAdd(s)
		@txWarnTO.push( s)
	end

	def GetTxName(i)
		return @txName[i]
	end

	def txNameAdd(s)
		@txName.push(s)
	end

end

################################################################################
#
#  Service Configuration struct init
#
class ServConfData
	def initialize
#   -------------------------------------- # general part
		@warnTO= 0
		@critTO= 0
		@totTO= 0

#   -------------------------------------- # each service part
		@testType=SELENIUM														# default mode is SeleniumIDE with Webdriver
# allowed: Jmeter, External
		@res= 'OK'
		@nTable= 0
		@nagServer= ''
		@nagService= ''

		@fOpTable= Array.new													# table names to execute
		@sTxData= nil															# put here TX data
	end


	attr_accessor :warnTO, :critTO, :totTO
	attr_accessor :nagServer, :nagService
	attr_accessor :res, :nTable, :fOpTable, :testType, :sTxData

	def fOpTable
		@fOpTable
	end

	def opTableAdd(s)
		@fOpTable.push(s)														#
	end

	def TxDataAdd(s)
		@sTxData=s
	end

end


