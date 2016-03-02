#!/usr/local/bin/ruby
################################################################################
#
#	By Sergio Boso		www.bosoconsulting.it
#
#	This software is covered by GPL license
#	It is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
#	WARRANTY OF DESIGN, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.
#	You can use and modify it but you must keep this message in it.
#
#	parameters:
#		none
################################################################################
# end.rb tenmplate
#	tobe moved in 
# 		/project_name/features/support
#

$LOAD_PATH.unshift(File.dirname(__FILE__))
if !defined?(XOpath)
	XOpath= File.expand_path(File.dirname(__FILE__))+'/../../../XOver/Src/'
end

require XOpath+'definitions.rb'

require 'rexml/document'
include REXML																	# so that we don't have to prefix everything with REXML::...

require 'optparse'
require 'pp'
require 'headless'
require 'OS'
require 'open3'
require 'timeout'
require 'net/smtp'

require 'watir-webdriver'														#open a browser WD mode
require 'watir-webdriver-performance'

require XOpath+'confRoutine.rb'
require XOpath+'logRoutine.rb'
require XOpath+'browserCommands.rb'


################################################################################
LONG	=20.0
SHORT	=3.0
RANGE 	=1.5

def thinkTimeShort
	$brws.XOwaitThinkTime([SHORT, SHORT* RANGE])
end

def thinkTimeLong
#	$brws.WaitTTime([20.0, 30.0])
	$brws.XOwaitThinkTime([LONG, LONG* RANGE])
end

################################################################################
#
#		Beginning of env setup
#
################################################################################

#	World do
#	end

Before do |scenario|
	if(scenario.respond_to? (:scenario_outline))
		scen= scenario.scenario_outline.name
	else
		scen= scenario.name
	end
	scen.gsub!(/[^0-9A-Za-z.\- ]/, '_')
	$gcfd.setUpServiceRes( scen, CUCUMBER, CUCUMBER)							# this is part of  XOver
	$brws.XOinitScreenShot
end

After do |scenario|
	# Do something after each scenario.
	# The +scenario+ argument is optional, but
	# if you use it, you can inspect status with
	# the #failed?, #passed? and #exception methods.
	if scenario.failed?
		e= scenario.exception.to_s
		if(e && !e.match(/Xover error/))
			$brws.setResCritical (e)
		end
	end
	if(scenario.outline?)
		scen= scenario.scenario_outline.name+' '+scenario.scenario_outline.cell_values[0]
		fname= scenario.scenario_outline.feature.file
	else
		scen= scenario.name
		fname= scenario.feature.file
	end

	res= $gcfd.calcServiceResCucumber( scen, File.basename(fname))				# insert scenario name & feature file name
end


###############################################################################

###############################################################################
AfterConfiguration do |config|
	if ENV.length!=0 && ENV['CONF']!=nil
		parms= ENV['CONF'], ENV['RUNID']
		applData=  ENV['DATA']
	else
		parms= './Cfg/cucumber.yml',''											# get command line info
	end

	$gcfd= GlobConfData.new(parms, false)										# read configuration information
	$gcfd.setUpOutput
	$brws= GenBrowser.new())													# create browser interface, normalmode

#	$testData= YAML.load(File.read(your datat))									# application specific actions

	at_exit do
		$gcfd.tearDown()
#		$gcfd.createIndex( 'index.html')
	end
	ret=OK
end

