################################################################################
#
#     HTML table management
#
#
require_relative 'definitions.rb'

class HtmlResultOutput
	def initialize(fullName, title, setSpacer, tabtype, append)
		@fullName= fullName
		@setSpacer= setSpacer
		@title= File.basename( @fullName, '.*')
		@append= append
		@tabType= tabtype
		@htmlTail = '</tbody></table></body></html>'
		@htmlHead = <<END
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html><head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<link rel="stylesheet" type="text/css" href="/Xover/resources/xover.css" media="all" />
<link rel="stylesheet" type="text/css" href="/Xover/resources/lightbox.css" media="screen" />
<title>
END

		@htmlStyles = <<END
</title></head>
<body style="color:#000000; background-color: #eaf1f7;">
<script type="text/javascript" src="/Xover/resources/lightbox-plus-jquery.js"></script>
<script>
	lightbox.option({
	  'resizeDuration': 10,
	  'wrapAround': true,
	  'fitImagesInViewport': true,
	  'maxWidth': 1280,
	  'maxHeight': 720
	})
</script>
END
# <table style="width: 1050px;" class="gridtable"><thead>
		@tableHead = <<END
<table class="gridtable"><thead>
END
		cucumberFlds=[ ['150', 'Date &amp; Time'],
					   ['80', 'Browser'],
					   ['280', 'Scenario'],
					   ['40', 'Result'],
					   ['40', 'Screen'],
					   ['40', 'Log'],
					   ['210', 'Message'],
					   ['50', 'TotTime'],
					   ['50', 'Twarn'],
					   ['50', 'Tcrit'],
					   ['120', 'TXname'],
					   ['60', 'TXtime'],
					   ['60', 'TXwarn'],
					   ['60', 'TXcrit']
		]
		standaloneFlds=[ ['120', 'Date &amp; Time'],
						 ['100', 'Server'],
						 ['280', 'Service'],
						 ['40', 'Result'],
						 ['40', ''],
						 ['40', ''],
						 ['210', 'Message'],
						 ['50', 'TotTime'],
						 ['50', 'Twarn'],
						 ['50', 'Tcrit'],
						 ['100', 'TXname'],
						 ['60', 'TXtime'],
						 ['60', 'TXwarn'],
						 ['60', 'TXcrit']
		]
		indexFlds=[    ['150', 'Creation Date &amp; Time'],
					   ['150', 'Modification Date &amp; Time'],
					   ['100', 'Config File name'],
					   ['100', 'Execution Host'],
					   ['100', 'Results &amp Details']
		]


		case @tabType
			when :cucumber
				@tableFields= cucumberFlds
			when :indextab
				@tableFields= indexFlds
			when :custom
				@tableFields= nil
			else
				@tableFields= standaloneFlds
		end

		if @tableFields
			@logIcon=$gcfd.resource_url+'/log.png'

			@logLink= '<td class="tdcenter"><a href="'+$gcfd.logURL+'"><img src="'+@logIcon+'" alt="See log fle" style="width:18px;height:18px;border:0;"></a>'+"</td>\n" 	# logs $gcfd.logURL
			@screenIcon= $gcfd.resource_url+'screenshot.png'

			@resHtml= Array.new
			@resHtml.push('<td class="tdpass">PASS</td>')
			@resHtml.push('<td class="tdwarn">WARN</td>')
			@resHtml.push('<td class="tdfail">FAIL</td>')
			@resHtml.push('<td class="tdunknw">UNKNWN</td>')
			self.setHeader( @tableFields, @title)
		end

	end

	def setHeader( header, title)
		@tableFields= header
		@tableSize= @tableFields.size
		@tableSize.times do |iField|
			@tableHead+= '<th style="width: '+@tableFields[iField][0].to_s+'px;"><h1>'+@tableFields[iField][1]+"</h1></th>\n"
		end

		@tableHead+= "</thead><tbody>\n"

		if @append
			self.openHtml( @fullName, title, @setSpacer)
		else
			self.newHtml( @fullName, title)
		end
	end

	def newHtml( fullName, title)
		@fHdl = File.new( fullName, 'wt')									# it does not exists, if exists, it will be overwritten
		@fHdl.puts @htmlHead+ title+ @htmlStyles+ @tableHead
	end

	def openHtml(fullName, title, setSpacer)
		if File.exists?( fullName)
			begin
				@fHdl= htmlSeek(fullName)
				if setSpacer
					self.addSpacer( '#2C3539')
				end
			rescue
				self.newHtml( fullName, title)
			end
		else
			self.newHtml( fullName, title)
		end
		return
	end

	def getHtmlTail( fullName)
		fSize= File.size( fullName)
		tailLen= [-fSize, -10000].max
		fh = File.new( fullName, 'r')												# open, pointer at the end
		fh.seek( tailLen, IO::SEEK_END)												# position near EOF
		tail=fh.read																# read to the end of file
		fh.close
		return tail
	end

	def htmlSeek(fullName)
		tail= getHtmlTail( fullName)
		tail_part= tail.split('</tbody>')
		if(tail_part.size>1)
			last_row= tail_part[0].split('<tr>').last
			scenario_num= /(\d+)/.match(last_row.split('<td')[3])[0]				# get scenario number from name
			$gcfd.iScenario= scenario_num.to_i+1

			offset= File.stat( fullName).size- tail.length+ tail_part[0].length  				# calc offset
			File.truncate( fullName, offset-1)										# truncate the file
			fh = File.new( fullName, 'a+')											# reopen for following processing, pointer at the end
#			fh.puts '</tr>'
		else
			puts 'No valid HTML file found: overwriting !'
			raise       														 	# if there is no 'tbody' clean up file
		end
		return fh
	end

	def addSpacer( color)
		@fHdl.puts "<tr>\n"
		@tableSize.times do |i|
			@fHdl.puts'<td class="tdsep"> </td>'
		end
		@fHdl.puts '</tr>'
	end

	def addScreen( fname, id, service, cl, src)
		cTime= File.mtime( fname).strftime("%Y-%m-%d %H:%M:%S")
		f_url= $gcfd.reportUrlBase+ File.basename(fname)
		r= '<a href="'+f_url +'" data-lightbox="'+id+'" data-title="'+service+' '+cTime+'">'
		r+= '<img '+cl+' src="'+src+ '"/></a>'+"\n"
		return r
	end

	def screenLinks( id, service, state, screenList)
		if(screenList!=nil)&&(screenList.size>0)
			res= @resHtml[state].split('>')[0]+'><div>'+"\n"
			res+= addScreen( screenList.first, id, service, 'class="tdicon"', @screenIcon)
			res+= '</div><div class="hiddenthumb" >'+"\n"
			screenList[1..-1].each do |s|
				res+= addScreen( s, id, service, '', $gcfd.reportUrlBase+s)
			end
			res+= '</div></td>'
		else
			res= '<td></td>'
		end
		return res
	end

	def getTxValues(txparms)
		s=''
		$pfd.servRes['txRes'].each do |n|
			if n.is_a?(Numeric)
				s+= sprintf('%.3f', n[txparms])+'<br>'
			else
				s+= n[txparms].to_s+'<br>'
			end
		end
		return s
	end

	def addHtmlResultData( server, service, state, resData)
		@fHdl.puts '<tr><td>' +resData['startTime'].strftime("%Y-%m-%d %H:%M:%S")+ '</td><td class="tdcenter">' +server+ '</td><td>' +service+ '</td>'
		@fHdl.puts @resHtml[state] + "\n" 										# PASS FAIL etc
		@fHdl.puts self.screenLinks(($gcfd.runId+' '+$gcfd.iScenario.to_s), service, state, (defined?($brws) ? $brws.screenList : nil))	# screen shot
		@fHdl.puts @logLink
		@fHdl.puts '<td>' +resData['applResMsg']+ "</td>\n" 					#
		tval=resData['perfData'].split(';')
		@fHdl.puts '<td class="tdright">' +sprintf('%.3f',resData['totTime'])+ "</td>\n" 		# TotTime
		@fHdl.puts '<td class="tdright">' +tval[1]+ "</td>\n" 									# Twarn
		@fHdl.puts '<td class="tdright">' +tval[2]+ "</td>\n" 									# Tcrit

		@fHdl.puts '<td class="tdright">' +getTxValues('TXname')+ "</td>\n" 					# TXname    $pfd.servRes.each['TXname']
		@fHdl.puts '<td class="tdright">' +getTxValues('TXdur')+ "</td>\n" 						# TXtime
		@fHdl.puts '<td class="tdright">' +getTxValues('TXCritTO')+ "</td>\n" 					# TXWarnTO
		@fHdl.puts '<td class="tdright">' +getTxValues('TXWarnTO')+ "</td>\n" 					# TXWarnTO

		@fHdl.puts '</tr>'
		@fHdl.flush
	end

	def addHtmlIndexData( resData)

		@fHdl.puts '<tr>'
		resData.each do |v|
			s=''
			if v.is_a?(String)
				s+='<td>'+v+'</td>'
			elsif v.is_a?(Hash)
				s+= '<td class="tdcenter"><a href="'+v['link']+'">'+v['text']+'</a></td>'
			end
			@fHdl.puts s
		end
		@fHdl.puts '</tr>'
	end

	def closeHtmlData( )
		@fHdl.puts @htmlTail
		@fHdl.close
	end

end
