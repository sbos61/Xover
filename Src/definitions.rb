################################################################################
# status constant
#

NOT_OK		=-1
OK			=0
WARNING		=1
CRITICAL	=2
UNKNOWN		=3
def errText(e)
	errT= ["OK", "WARNING", "CRITICAL", "UNKNOWN"]  
	return errT[e]
end

# run mode
PLUGIN		=0
PASSIVE		=1
STANDALONE	=2
CUCUMBER	=3

# test type
SELENIUM	=10
JMETER		=11
EXTERNAL	=12
