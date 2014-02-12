def open(links)
  links.each {|link| system("open #{link}")}

  puts "It's been a pleasure serving you your favorite websites!"
  puts "Did you know you can use tags to serve specific site groups? " +
    "See the documentation for details." if ARGV.empty?
end

links = ["http://www.gmail.com", "http://www.facebook.com"]
open(links)