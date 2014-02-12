class WebOpener
  KNOWN_TAGS = {
    :help => ['-h','--help'],
    :links => ['-l','--links'],
    :all => ['-a', '--all']
  }
  LINKFILE = File.dirname(__FILE__) + '/check_everything/links.txt'

  def run
    @argv = ARGV.map(&:downcase)
    extract_links

    # First check for unknown arguments and print out a helpful message.
    known_tags = KNOWN_TAGS.values.flatten + @links.keys
    unmatched_args = @argv.select{ |arg| !known_tags.include?(arg)}
    if !unmatched_args.empty?
      puts "\nUnknown option#{@argv.size > 1 ? "s" : nil}: " +
        "#{unmatched_args.join(" ")}"
      print "usage: check_everything"
      KNOWN_TAGS.values.flatten.each {|tag| print " [#{tag}]"}
      puts "\n\nHint: Enter 'check_everything --help' to see the options!"
      puts "\n"
    
    # Print out a help message.
    elsif @argv.any? {|arg| KNOWN_TAGS[:help].include?(arg)}
      help

    # Edit the tags and links.
    elsif @argv.any? {|arg| KNOWN_TAGS[:links].include?(arg)}
      system("open #{LINKFILE}")
    
    # Open up the websites!
    else
      open
    end
  end
  
  private
  def help
    puts "\n'check_everything' will open all sites labeled with the 'default' tag."
    puts
    puts "Available tags:"
    puts "   -h, --help                 display the help message"
    puts "   -t, --tags,                view/edit links and tags"
    puts "   -a, --all                  open all websites"
    puts "   <tags>                     open a specific site group"
    puts
    puts "Note: The first tag in this list will be the only tag evaluated."
    puts
  end

  def open
    @argv << "default" if @argv.empty?
    
    # If -a or --all is specified, select all links.  Otherwise, select specified
    # links, or the default links if none are specified.
    if @argv.any?{|arg| KNOWN_TAGS[:all].include?(arg)}
      links = @links.values.flatten.uniq
    else
      links = @argv.map{|tag| @links[tag]}.flatten.compact.uniq
    end

    links.each do |url|
      url = "http://" << url if !url.start_with?("http")
      system("open #{url}")
    end

    puts "\nIt's been a pleasure serving up your favorite websites!"
    puts "Did you know you can use categories to open specific site groups? " +
      "Enter 'check_everything --links' for details.\n" if ARGV.empty?
  end

  def read_file(file_name)
    file = File.open(file_name, "r")
    data = file.read
    file.close
    data
  end

  def extract_links
    link_file = read_file(LINKFILE).split("\n")
    cur_tags = []
    
    @links = {}
    link_file.each do |line|
      if line.start_with?("&&")
        # add tags as keys in @links, and assign to cur_tags
        cur_tags = add_tag(line[2..-1].strip).flatten
      elsif line.start_with?("--")
        # add links to each relevant tag in @links
        cur_tags.each { |tag|
          @links[tag] << line[2..-1].strip
        }
      end
    end
  end

  # Recursive helper method for extract_links
  def add_tag(line)
    line.downcase!
    # Add multiple tags, if separated by semicolons.
    if line.include?(";")
      line.split(";").map(&:strip).each do |tag|
        add_tag(tag.strip)
      end
    else
      # Raise an error if there is an invalid tag.
      tag_space_message = "Your link file includes a tag with a space in it; " +
        "please fix by entering 'check_everything -t' into your command line."
      has_dash_message = "Your linke file includes a tag with a dash, which is " +
        "not allowed; please fix by entering 'check_everything -t' into your command line."
      raise tag_space_message if line.match(/ /)
      raise has_dash_message if line.match(/-/)
      @links[line] ||= []
      [line]
    end
  end
end

WebOpener.new.run