#!/usr/bin/env ruby
require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'uri'
require 'ruby-progressbar'
require 'optparse'
require 'peach'

REQUEST_URL = "http://dslr-kleinanzeigen.de/index.php?suche="

class Item
	attr_accessor :name
	attr_accessor :date
	attr_accessor :price
	attr_accessor :href
	attr_accessor :status

	def initialize(name, date, price, href, status)
		@name=name
		@date=date
		@price=price
		@href=href
		@status=status
	end

	def display()
		puts "#@name"
		puts "#@date"
		puts "#@price"
		puts "#@href"
		puts "---------------------------------------------------------------"
	end

	def display_with_index(index)
		puts "[#{index}] #@name"
		puts "[#{index}] #@date"
		puts "[#{index}] #@price"
		puts "#@href"
		puts "---------------------------------------------------------------"
	end

	def parse_status()
		subHost = URI.parse(self.href).host
		begin
			subPage = Nokogiri::HTML(open(self.href))
		rescue Exception => e
			self.status = false
			return
		end

		if subHost == "www.dslr-forum.de"
			subStatus = subPage.css("tr td.navbar strong strong")[0]
			unless subStatus.nil? || subStatus == 0
				if subStatus.text == "[Biete]"
					self.status = true
				end
			end

		elsif subHost == "www.dforum.net"
			subStatus = subPage.css("tr td.navbar strong b")[0]
			unless subStatus.nil? || subStatus == 0
				if subStatus.text == "Biete:"
					self.status = true
				end
			end

		elsif subHost == "www.nikon-fotografie.de"
			subStatus = subPage.css("span.smallfont b font")[0]
			unless subStatus.nil? || subStatus == 0
				if subStatus.text != "VERKAUFT!"
					self.status = true
				end
			end

		elsif subHost == "forum.foto-faq.de"
			self.status = true

		elsif subHost == "www.traumflieger.de"
			self.status = true

		else
			PROGRESSBAR.log "[!] ------------------------------------------------"
			PROGRESSBAR.log "[!] Unbekannte Domain: #{subHost}"
			PROGRESSBAR.log "[!] #{self.href}"
			PROGRESSBAR.log "[!] ------------------------------------------------"
		end

		PROGRESSBAR.increment
	end #pase_status
end

options = {:days => 365}

optparse = OptionParser.new do|opts|
	opts.banner = "Usage: dslr.rb [options]"

	opts.on('-d', '--days days', 'Days -- Standard 365') do |days|
		options[:days] = days;
	end

	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end

	opts.on('-v', '--version', 'Show version') do
		puts "Ver.: 1.0"
		exit
	end
end #Parser

begin
	optparse.parse!
	mandatory = []                                         # Enforce the presence of
	missing = mandatory.select{ |param| options[param].nil? }        # the -t and -f switches
	if not missing.empty?                                            #
		puts "Missing options: #{missing.join(', ')}"                  #
		puts optparse                                                  #
		exit                                                           #
	end                                                              #

	if ARGV.empty?
		puts "Missing argument"
		puts optparse
		exit
	end

	page = URI.parse(REQUEST_URL + URI::encode(ARGV.first))

rescue OptionParser::InvalidOption, OptionParser::MissingArgument      #
	puts $!.to_s                                                           # Friendly output when parsing fails
	puts optparse                                                          #
	exit                                                                   #
end
if page = Nokogiri::HTML(open(page))

	allTableRows = page.css("table tr.Zeileklein, table tr.Zeile")
	countItems = allTableRows.length/2

	if countItems > 0
		arrayOfItems = Array.new

		puts "Items found: #{countItems}"

		i = 0
		until i == countItems  do
			# row 0
			aDate = Date.strptime(allTableRows.at(i).css("td.timing").text, "%d.%m.%y %H:%M")

			if options[:days] != nil
				till = (Date.today - options[:days].to_i)
				if aDate < till.to_date
					i += 1
					next
				end
			end

			#row 1
			aPrice = allTableRows.at(countItems+i).css("td.pricing").text
			aName = allTableRows.at(countItems+i).css("td.titling").text
			aHref = allTableRows.at(countItems+i).css("a")[0]["href"]

			#new Item
			item = Item.new(aName, aDate, aPrice, aHref, false)
			arrayOfItems.push(item)
			i += 1
		end
	else
		puts "No Items found"
		exit
	end

	PROGRESSBAR = ProgressBar.create(:format => '%t |%b%i| %p%% %a',:title => "Parsing", :starting_at => 0, :total => arrayOfItems.length)
	PROGRESSBAR.log "Items to parse: #{arrayOfItems.length} (check Date)"

	# parsing all Items
	arrayOfItems.peach do |aItem|
		aItem.parse_status
	end

	# Nach Datum sortieren
	arrayOfItems.sort! { |a,b| a.date <=> b.date }

	i = 0
	avgPrice = 0
	puts

	arrayOfItems.each do |aItem|
		if aItem.status == true
			i += 1
			avgPrice = avgPrice + aItem.price.to_f
			aItem.display_with_index(i)
		end
	end

	if i == 0
		puts "No Items match"
		exit
	else
		puts "#{i} Items match - Average Price: #{(avgPrice/i).round(2)} €"
	end


end