# bulletin.rb
# A link-blog, static site generator built on top of pinboard.in.

require 'open-uri'
require 'rss'
require 'rubygems'
require 'time'

# Gems

require 'aws/s3'
require 'json'
require 'redcarpet'
require 'zip/zip'

BULLETIN_VERSION = "0.8.3"
BULLETIN_PINBOARD_USERNAME = "kyleobrien"
BULLETIN_PINBOARD_TAG = "bulletin"
BULLETIN_PIBOARD_ITEM_COUNT = "20"
BULLETIN_SITE_TITLE = "Kyle O&rsquo;Brien / Links"
BULLETIN_SITE_DESCRIPTION = "A compilation of the day's interesting links, collected by [Kyle](http://kyleobrien.net). Updated nightly (usually). Everything on this site is made available to you under a [Creative Commons License](http://creativecommons.org/licenses/by/3.0/). We're running on [bulletin](https://github.com/kyleobrien/bulletin), a link-blog, static site generator built on top of [Pinboard](http://pinboard.in)."
BULLETIN_S3_BUCKET_NAME = "linksbackup.kyleobrien.net"
BULLETIN_RSS_AUTHOR = "Kyle O&rsquo;Brien"
BULLETIN_RSS_TITLE = "links"
BULLETIN_RSS_LINK = "http://kyleobrien.net/links/"

def produceHtmlHeader(page_type)
	date = ""
	title = ""
	markdown = Redcarpet::Markdown.new(Redcarpet::Render::XHTML, {})	   
	if (page_type == "home")
		date = Time.now.strftime("%A, %B %e").lstrip
		title = "#{BULLETIN_SITE_TITLE} - Home" 
	elsif (page_type == "archive")
		date = Time.now.strftime("%B %e").lstrip
		title = "#{BULLETIN_SITE_TITLE} - #{date}"
	else
		date = "ERR"
		title = "#{BULLETIN_SITE_TITLE} - ERR"
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
	html_header += "\t\t<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">"
	html_header += "\t\t<meta name=\"apple-mobile-web-app-title\" content=\"links\">"
	html_header += "\t\t<meta name=\"viewport\" content=\"width=device-width\">\n"
	html_header += "\t\t<title>#{title}</title>\n"
	html_header += "\t</head>\n\t<body>\n"
	html_header += "\t\t<h1>#{BULLETIN_SITE_TITLE}</h1>\n"
	html_header += "\t\t<div id=\"container\">\n"
	html_header += "\t\t\t<div id=\"update-time\">\n"
	html_header += "\t\t\t\t<span>Last updated: <time>#{date}</time></span>\n"
	html_header += "\t\t\t</div>\n"
        html_header += "\t\t\t<div id=\"site-description\">\n"
	html_header += "\t\t\t#{markdown.render(BULLETIN_SITE_DESCRIPTION)}"
    html_header += "\t\t\t</div>\n"
end

def produceItemHtmlFromBookmark(bookmark)
	html_item = ""
    html_item += "\t\t\t\t<li>\n"
	html_item += "\t\t\t\t\t<a href=\"#{bookmark["u"]}\">#{bookmark["d"]}</a>\n"

    markdown = Redcarpet::Markdown.new(Redcarpet::Render::XHTML, {})
    html_item += "\t\t\t\t\t#{markdown.render(bookmark["n"])}\n"

    html_item += "\t\t\t\t\t<time datetime=\"#{bookmark["dt"]}\" />\n"
	html_item += "\t\t\t\t</li>\n"

	return html_item
end

def deleteZipBackup(filename)
	if (File.exists?(filename))
		begin
			file = File.delete(filename)
		rescue => err
			puts "Couldn't delete the local, temporary zip file!"
			puts err
		end
	end	
end

# ================
# =  SCRIPT GO!  =
# ================

script_start_time = Time.now

# Redirect the standard output to log..
directory_for_script = File.expand_path(File.dirname(__FILE__))
$stdout = File.new("#{directory_for_script}/bulletin.log", "a")
$stdout.sync = true

timestamp = script_start_time.strftime("%Y-%m-%dT%H:%M:%S%z").lstrip
puts "============================"
puts "#{timestamp}"


# Grab the JSON-formatted feed from pinboard.
puts "Grab the JSON-formatted feed from pinboard."

parsed_json = nil
json_url = "http://feeds.pinboard.in/json/u:#{BULLETIN_PINBOARD_USERNAME}/t:#{BULLETIN_PINBOARD_TAG}/?count=#{BULLETIN_PIBOARD_ITEM_COUNT}"

open(json_url, "User-Agent" => "bulletin/#{BULLETIN_VERSION}") { |file|
	parsed_json = JSON.parse(file.read)
}


# Pull out relevant information from each item in the JSON response.
puts "Pull out relevant information from each item in the JSON response."

html_list = ""
archive_array = []

unless (parsed_json.nil?)
	parsed_json.each { |bookmarked_item|
		time = Time.parse(bookmarked_item["dt"], '%Y-%m-%dT%H:%M:%S%z')

		# Only include the item if it was posted in the last day.
		if (script_start_time.tv_sec - time.tv_sec < (60 * 60 * 24))
			html_item = produceItemHtmlFromBookmark(bookmarked_item)

			html_list = html_item + html_list
			archive_array << bookmarked_item
		end
	}

	# Each day's archive should sort oldest to newest.
	if (!archive_array.empty?)
		archive_array.reverse!
	end
end


# Assemble the webpage.
puts "Assemble the webpage."

html_header = produceHtmlHeader("home")
html_list = "\t\t<ul>\n" + html_list + "\t\t</ul>\n"
html_list += "\t\t</div>\n\t</body>\n</html>"
html = html_header + html_list


# Do a bunch of stuff only if there's new content today.
if (!archive_array.empty?)


	# Write index.html to disk.
	puts "Write index.html to disk"

	begin
		file = File.new("#{directory_for_script}/index.html", "w")
		file.write(html)
		file.close
	rescue => err
		puts "Couldn't write to index.html!"
		puts err
	end


	# Archive the day's JSON. Create the necessary heirarchy.
	puts "Archive the day's JSON."

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
	
	json_to_save = JSON.generate(archive_array)
	json_filename = Time.now.strftime("%Y%m%d")
	begin
		file = File.new("#{month_path}/#{json_filename}.json", "w")
		file.write(json_to_save)
		file.close
	rescue => err
		puts "Couldn't write today's JSON!"
		puts err
	end


	# Create (or re-create) the archive page for the current month
	# TODO: This doesn't actually work!
	puts "Create (or recreate) the archive page for the current month"

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

	
	# Create RSS feed.
	puts "Create RSS feed."
	
	rss = RSS::Maker.make("atom") do |maker|
		maker.channel.author = BULLETIN_RSS_AUTHOR
		maker.channel.updated = Time.now.to_s
		maker.channel.about = "http://www.ruby-lang.org/en/feeds/news.rss"
		maker.channel.title = BULLETIN_RSS_TITLE
		maker.channel.link = BULLETIN_RSS_LINK
	
		archive_array.each { |bookmarked_item|
			maker.items.new_item do |item|
				item.link = "#{bookmarked_item["u"]}"
				item.title = "#{bookmarked_item["d"]}"
                markdown = Redcarpet::Markdown.new(Redcarpet::Render::XHTML, {})
				item.description = markdown.render(bookmarked_item["n"])
				item.updated = "#{bookmarked_item["dt"]}"
			end
	    }
	end
	
	begin
		file = File.new("#{directory_for_script}/links.atom", "w")
		file.write(rss)
		file.close
	rescue => err
		puts "Couldn't write RSS feed!"
		puts err
	end


	# Zip up the contents of the site..
	puts "Zip up the contents of the site."
	
	zip_filename = directory_for_script + '/' + json_filename + '.zip'
	deleteZipBackup(zip_filename)
	
	Zip::ZipFile.open(zip_filename, Zip::ZipFile::CREATE) do |zipfile|
		filenames = ['index.html', 'main.css', 'links.atom', 'favicon.ico', 'touch-icon-ipad-precomposed.png', 'touch-icon-ipad-retina-precomposed.png', 'touch-icon-iphone-precomposed.png', 'touch-icon-iphone-retina-precomposed.png']
		filenames.each do |filename|
			zipfile.add(filename, directory_for_script + '/' + filename)
		end
		
		Dir.glob(archive_path + '/*/') { |year_folder|
			year = year_folder.split('/').last
			Dir.glob(year_folder + '/*/') { |month_folder|
				month = month_folder.split('/').last
				Dir.glob(month_folder + '/*') { |json_file|
					relative_path = 'archive/' + year + '/' + month + '/' + File.basename(json_file)
					zipfile.add(relative_path, json_file)
				}
			}
		}
	end

	
	# Upload zip file to S3.
	puts "Upload zip file to S3."
	
	access_key_id = 'access_key_id_placeholder'
	secret_access_key = 'secret_access_key_placeholder'
	begin
		File.open("#{directory_for_script}/.amazon_keys", 'r').each_line do |line|
			components = line.strip.split('=')
			if (components[0] == 'access_key_id')
				access_key_id = components[1]
			elsif (components[0] == 'secret_access_key')
				secret_access_key = components[1]
			end
		end
	rescue => err
		puts "Couldn't open amazon key file."
		puts err
	end

	AWS::S3::Base.establish_connection!(
		:access_key_id => access_key_id,
		:secret_access_key => secret_access_key
	)
	
	if (!AWS::S3::Service.buckets.include?(BULLETIN_S3_BUCKET_NAME))
		AWS::S3::Bucket.create(BULLETIN_S3_BUCKET_NAME)
	end
	
	file = json_filename + '.zip'
	AWS::S3::S3Object.store(file, open(zip_filename), BULLETIN_S3_BUCKET_NAME)

	AWS::S3::Base.disconnect!()
	
	deleteZipBackup(zip_filename)	
end

puts "Script execution complete."

# ===================
# =  END OF SCRIPT  =
# ===================


# Restore standard output.

$stdout = STDOUT

