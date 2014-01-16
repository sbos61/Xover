
msg=['prova','test','altro']
fname='test.log'
fHdl = File.new( fname, "a+")
text= msg.join(',')

t = Time.now
line= t.strftime("%Y-%m-%d %H.%M.%S")+ ' - '+ text
fHdl.puts line
fHdl.close