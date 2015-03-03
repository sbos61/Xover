################################################################################
#
#     HTML table management
#
#
require_relative 'definitions.rb'

class HtmlOutput
	def initialize(fullName, title, setSpacer, runMode)
		@fullName= fullName

		@htmlTail = '</tbody></table></body></html>'
		@htmlHead = <<END
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html><head>
<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1"><title>
END

		@htmlStyles = <<END
</title><style type="text/css">
h1 {text-align: center; font-weight: bold;color:Black;font-family:arial;font-size:12px}
th1 {text-align: center; font-weight: bold;color:Black;font-family:helvetica;font-size:14px}
br1 {text-align: right;color:Black;font-family:arial;font-size:10px}
bl1 {text-align: left;color:Black;font-family:arial;font-size:10px}
bc {text-align: center; color: Black; font-family: Arial,Helvetica,sans-serif;font-size:12px}
table.gridtable {
 font-family: arial; font-size:10px; border-width: 1px; border-color: #000000;
 border-collapse: collapse; cellspacing: 1px; table-layout: fixed; width: 1050px;
}
table.gridtable th {
 border: 1px solid black; padding: 2px; background-color: #aaaaaa;
}
table.gridtable td {
 border: 1px solid black; padding: 2px; background-color: #eaf1f7;
}
</style></head>
END

		cucumberHead = <<END
<body style="color:#000000; background-color: #eaf1f7;" alink="#000099" link="#000099" vlink="#990099">
<table class="gridtable">
<thead>
END
		cucumberFlds=[ ['120', 'Date &amp; Time'],
					   ['70', 'Browser'],
					   ['220', 'Scenario'],
					   ['50', 'Result'],
					   ['210', 'Message'],
					   ['50', 'TotTime'],
					   ['50', 'Twarn'],
					   ['50', 'Tcrit'],
					   ['100', 'TXname'],
					   ['50', 'TXtime'],
					   ['50', 'TXwarn'],
					   ['50', 'TXcrit']
		]
		@headSize=cucumberFlds.size

		@headSize.times do |iField|
			cucumberHead+= '<th style="width: '+cucumberFlds[iField][0]+'px;"><h1>'+cucumberFlds[iField][1]+"</h1></th>\n"
		end
		cucumberHead+= "</thead><tbody>\n"
		standaloneHead = <<END

<body style="color:#000000; background-color: #eaf1f7;" alink="#000099" link="#000099" vlink="#990099">
<table class="gridtable">
<thead>
<th style="width: 120px;"><h1>Date &amp; Time</h1></th>
<th style="width: 120px;"><h1>Server</h1></th>
<th style="width: 170px;"><h1>Service</h1></th>
<th style="width: 50px;"><h1>Result</h1></th>
<th style="width: 210px;"><h1>Message</h1></th>
<th style="width: 50px;"><h1>TotTime</h1></th>
<th style="width: 50px;"><h1>Twarn</h1></th>
<th style="width: 50px;"><h1>Tcrit</h1></th>
<th style="width: 100px;"><h1>TXname</h1></th>
<th style="width: 50px;"><h1>TXtime</h1></th>
<th style="width: 50px;"><h1>TXwarn</h1></th>
<th style="width: 50px;"><h1>TXcrit</h1></th>
</thead>
<tbody>
END

		case runMode
			when CUCUMBER
				@tableHead= cucumberHead
			when STANDALONE
				@tableHead= standaloneHead
			else
				@tableHead= ''
		end
		@resHtml= Array.new
		@resHtml.push('<td style="background-color: #00ff00; text-align: center;"><bc>PASS</bc></td>')
		@resHtml.push('<td style="background-color: #FFFF66; text-align: center;"><bc>WARN</bc></td>')
		@resHtml.push('<td style="background-color: red; text-align: center;"><bc>FAIL</bc></td>')
		@resHtml.push('<td style="background-color: blue; text-align: center;"><bc>UNKNW</bc></td>')
#		@resHtml.push('<td style="background-color: #2C3539; text-align: center;"><bc></bc></td>')           # gunmetal
		self.openHtml(fullName, title, setSpacer)
	end

	def openHtml(fullName, title, setSpacer)
		if File.exists?( fullName)
			begin
				@fHdl= htmlSeek(fullName)
				if setSpacer
					self.addSpacer( '#2C3539')
				end
			rescue
				@fHdl = File.new( fullName, 'wt')										# it does not exists, if exists, it will be overwritten
				@fHdl.puts @htmlHead+ title+ @htmlStyles+ @tableHead
			end
		else
			@fHdl = File.new( fullName, 'wt')										# it does not exists, if exists, it will be overwritten
			@fHdl.puts @htmlHead+ title+ @htmlStyles+ @tableHead
		end
		return
	end

	def htmlSeek(fullName)
# 		tail_part= []
		fh = File.new( fullName, 'r')											# open, pointer at the end
		fh.seek(-200, IO::SEEK_END)												# position near EOF
		tail=fh.read															# read to the end of file
		tail_part= tail.split('</tbody>')
		fh.close

		if(tail_part.size>1)
			offset= tail_part[0].length+  File.stat( fullName).size-200				# calc offset
			File.truncate( fullName, offset-1)										# truncate the file

			fh = File.new( fullName, 'a+')											# reopen for following processing, pointer at the end
			fh.puts '</tr>'
		else
			puts 'No valid HTML file found: overwriting !'
			raise       														 	# if there is no 'tbody' clean up file
		end
		return fh
	end

	def addSpacer( color)
		@fHdl.puts "<tr>\n"
		@headSize.times do |i|
			@fHdl.puts'<td style="background-color: '+color+' "> </td>'
		end
		@fHdl.puts '</tr>'
	end

	def addHtmlData( nagserver, nagservice, state, msg)
		msg_part= []
		p2= []
		p3= []
		txr= []
		msg_part= msg.split('|')												# split message and values
		p2= msg_part[1].split(' ')												# get values for each TX

		t = Time.now
		@fHdl.puts "<tr>\n<td>" +t.strftime("%Y-%m-%d %H:%M:%S")+ '</td><td>' +nagserver+ '</td><td>' +nagservice+ '</td>'
		@fHdl.puts @resHtml[state] + "\n<td>" + msg_part[0] + '</td>'

		p3= p2[0].split(/(\w*)=([0-9.]*)[s;]*([0-9.]*);([0-9.]*)/)				# Whole service: separa in pezzi di numeri  lettere
		p3.shift																# skip first element
		@fHdl.puts '<td style="text-align: right;">' + p3[1] + '</td>'				# this is the Whole servicedur
		@fHdl.puts '<td style="text-align: right;">' + p3[2] + '</td>'				# this is the Whole servicewarn th
		@fHdl.puts '<td style="text-align: right;">' + p3[3] + '</td>'				# this is the Whole servicefail th

		p2.shift																# delete whole service data
		ntx= p2.size
		4.times do |i|
			txr[i]=''
		end

		ntx.times do |itx|
			p3= p2[itx].split(/(\w*)=([0-9.]*)[s;]*([0-9.]*);([0-9.]*)/)		# Main TX: separa in pezzi di numeri  lettere
			p3.shift															# skip first element
			4.times do |i|
				txr[i].concat( p3[i]+ '<br>')
			end
		end

		@fHdl.puts '<td>' + txr[0] + '</td>'										# this are the TX names
		3.times do |i|
			@fHdl.puts '<td style="text-align: right;">' + txr[i+1] + '</td>'		# this are the TX times
		end
		@fHdl.puts '</tr>'
	end

	def closeHtmlData( )
		@fHdl.puts @htmlTail
		@fHdl.close
	end

end
