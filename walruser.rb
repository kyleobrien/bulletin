# walruser.rb
# Scraper for 'linked list' style blog that's built on pinboard.in

require 'open-uri'
require 'rss'
require 'rubygems'
require 'time'

# Gems

require 'json'
require 'rdiscount'

WALRUSER_VERSION = "0.8.1"
WALRUSER_PINBOARD_USERNAME = "kyleobrien"
WALRUSER_PINBOARD_TAG = "rtw"
WALRUSER_PIBOARD_ITEM_COUNT = "20"
WALRUSER_SITE_TITLE = "Ride the Walrus!"
WALRUSER_SITE_DESCRIPTION = "A compilation of the day's interesting links, collected by [Kyle](http://kyleobrien.net), and presented here for your edification. Updated nightly (usually). Everything on this site is made available to you under a [Creative Commons License](http://creativecommons.org/licenses/by/3.0/). We're running on [PROJECT A2](), a static site generator built on top of [Pinboard](http://pinboard.in). It's open source too, so check it out."

def produceHtmlHeader(page_type)
	date = ""
	title = ""
	markdown = RDiscount.new(WALRUSER_SITE_DESCRIPTION)
	
	if (page_type == "home")
		date = Time.now.strftime("%A, %B %e").lstrip
		title = "#{WALRUSER_SITE_TITLE} - Home" 
	elsif (page_type == "archive")
		date = Time.now.strftime("%B %e").lstrip
		title = "#{WALRUSER_SITE_TITLE} - #{date}"
	else
		date = "ERR"
		title = "#{WALRUSER_SITE_TITLE} - ERR"
	end

	html_header = "<html lang=\"en\">\n\t<head>\n"
	html_header += "\t\t<link rel=\"shortcut icon\" href=\"favicon.ico\" />\n"
	html_header += "\t\t<link rel=\"stylesheet\" type=\"text/css\" href=\"main.css\" />\n"
	html_header += "\t\t<link rel=\"alternate\" type=\"application/atom+xml\" title=\"Links\" href=\"links.atom\" />\n"
	html_header += "\t\t<link rel=\"apple-touch-icon-precomposed\" href=\"touch-icon-iphone-precomposed.png\" />\n"
	html_header += "\t\t<link rel=\"apple-touch-icon-precomposed\" sizes=\"72x72\" href=\"touch-icon-ipad-precomposed.png\" />\n"
	html_header += "\t\t<link rel=\"apple-touch-icon-precomposed\" sizes=\"114x114\" href=\"touch-icon-iphone-retina-precomposed.png\" />\n"
	html_header += "\t\t<link rel=\"apple-touch-icon-precomposed\" sizes=\"144x144\" href=\"touch-icon-ipad-retina-precomposed.png\" />\n"
	html_header += "\t\t<meta charset=\"utf-8\">\n"
	html_header += "\t\t<meta name=\"viewport\" content=\"width=device-width\">\n"
	html_header += "\t\t<title>#{title}</title>\n"
	html_header += "\t</head>\n\t<body>\n"
	html_header += "\t\t<h1>#{WALRUSER_SITE_TITLE}</h1>\n"
	html_header += "\t\t<div id=\"container\">\n"
	html_header += "\t\t\t<div id=\"update-time\">\n"
	html_header += "\t\t\t\t<span>Last updated: <time>#{date}</time></span>\n"
	html_header += "\t\t\t</div>\n"
    html_header += "\t\t\t<div id=\"site-description\">\n"
	html_header += "\t\t\t#{markdown.to_html}"
    html_header += "\t\t\t</div>\n"
end

def produceItemHtmlFromBookmark(bookmark)
	html_item = ""
    html_item += "\t\t\t\t<li>\n"
	html_item += "\t\t\t\t\t<a href=\"#{bookmark["u"]}\">#{bookmark["d"]}</a>\n"

    markdown = RDiscount.new(bookmark["n"])
    html_item += "\t\t\t\t\t#{markdown.to_html}\n"

    html_item += "\t\t\t\t\t<time datetime=\"#{bookmark["dt"]}\" />\n"
	html_item += "\t\t\t\t</li>\n"

	return html_item
end

script_start_time = Time.now

# Redirect the standard output.

directory_for_script = File.expand_path(File.dirname(__FILE__))
$stdout = File.new("#{directory_for_script}/walruser.log", "a")
$stdout.sync = true


# Grab the JSON-formatted feed from pinboard.

parsed_json = nil
json_url = "http://feeds.pinboard.in/json/u:#{WALRUSER_PINBOARD_USERNAME}/t:#{WALRUSER_PINBOARD_TAG}/?count=#{WALRUSER_PIBOARD_ITEM_COUNT}"

open(json_url, "User-Agent" => "RIDETHEWALR.US/#{WALRUSER_VERSION}") { |file|
	parsed_json = JSON.parse(file.read)
}


# Pull out relevant information from each item in the JSON.

html_list = ""
array_for_archiving = []
unless (parsed_json.nil?)
	parsed_json.each { |bookmarked_item|
		time = Time.parse(bookmarked_item["dt"], '%Y-%m-%dT%H:%M:%S%Z')
		if (script_start_time.tv_sec - time.tv_sec < (60 * 60 * 24))
			html_item = produceItemHtmlFromBookmark(bookmarked_item)
			html_list = html_item + html_list
			array_for_archiving << bookmarked_item
		end
	}
	if (!array_for_archiving.empty?)
		array_for_archiving.reverse!
	end
end


# Put together the webpage.

html_header = produceHtmlHeader("home")

if (!array_for_archiving.empty?)
	html_list = "\t\t<ul>\n" + html_list + "\t\t</ul>\n"
    html_list += "\t\t</div>\n\t</body>\n</html>"
end

html = html_header + html_list

if (!array_for_archiving.empty?)

	# Write index.html to disk.

	begin
		file = File.new("#{directory_for_script}/index.html", "w")
		file.write(html)
		file.close
	rescue => err
		puts "Couldn't write to index.html!"
		puts err
	end

	# Archive the existing JSON
	
	archive_path = File.join(directory_for_script, "archive")
	if !File.directory?(archive_path)
		Dir.mkdir(archive_path, 0700)
	end
	
	year = Time.now.strftime("%Y")
	year_path = File.join(archive_path, year)
	if !File.directory?(year_path)
		Dir.mkdir(year_path, 0700)
	end
	
	month = Time.now.strftime("%m")
	month_path = File.join(year_path, month)
	if !File.directory?(month_path)
		Dir.mkdir(month_path, 0700)
	end
	
	json_to_save = JSON.generate(array_for_archiving)
	json_filename = Time.now.strftime("%Y%m%d")
	begin
		file = File.new("#{month_path}/#{json_filename}.json", "w")
		file.write(json_to_save)
		file.close
	rescue => err
		puts "Couldn't write today's json!"
		puts err
	end

	# Create (or re-create) the archive page for the current month

	page_list = ""
	Dir.glob(month_path + "/*.json") { |filename|
	    file = File.new(filename, "r")	
        json = JSON.parse(file.read)
		html_list = ""
		unless (json.nil?)
			json.each { |bookmarked_item|
				html_item = produceItemHtmlFromBookmark(bookmarked_item)
				html_list = html_item + html_list
			}
		end

		page_list = page_list + html_list
	}

	# header won't have right date with archive
	html = produceHtmlHeader("archive") + page_list

	begin
		#file = File.new("#{directory_for_script}/index.html", "w")
		#file.write(html)
		#file.close
	rescue => err
		puts "Couldn't write to index.html!"
		puts err
	end

	
	# Create RSS feed
	
	rss = RSS::Maker.make("atom") do |maker|
		maker.channel.author = "Kyle O'Brien"
		maker.channel.updated = Time.now.to_s
		maker.channel.about = "http://www.ruby-lang.org/en/feeds/news.rss"
		maker.channel.title = "ridethewalr.us"
		maker.channel.link = "http://ridethewalr.us/"
	
		array_for_archiving.each { |bookmarked_item|
			maker.items.new_item do |item|
				item.link = "#{bookmarked_item["u"]}"
				item.title = "#{bookmarked_item["d"]}"
                markdown = RDiscount.new(bookmarked_item["n"])
				item.description = markdown.to_html
				item.updated = "#{bookmarked_item["dt"]}"
			end
	}
	end
	
	# save the rss to a file
	begin
		file = File.new("#{directory_for_script}/links.atom", "w")
		file.write(rss)
		file.close
	rescue => err
		puts "Couldn't write RSS feed!"
		puts err
	end
end

# Restore standard output.

$stdout = STDOUT

