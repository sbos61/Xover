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
TEST		=4

# test type
SELENIUM	=10
JMETER		=11
EXTERNAL	=12

STEP= 0.5
SEC30= (30/STEP).round

################################################################################
#
#   Table definitions for formatters
#

NAMEW= 400                  	# pixel
FILEW= 200                      # pixel
TAGW= 50                        # pixel

NAMECHAR= 100                   # chars
