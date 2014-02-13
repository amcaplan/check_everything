class CheckEverything
  KNOWN_TAGS = {
    :help => ['-h','--help'],
    :links => ['-l','--links'],
    :categories => ['-c', '--categories'],
    :all => ['-a', '--all']
  }
  LINKFILE = "#{File.expand_path('~')}/.check_everything_links"

  def self.run
    @argv = ARGV.map(&:downcase)
    # Create a new link file if none has been created yet
    unless File.exists?(LINKFILE)
      system("cp #{File.dirname(__FILE__)}/check_everything/links.txt #{LINKFILE}")
      @argv = ["-l"]
      puts "Please customize your installation.",
        "This message will only be shown once.",
        "To open again and customize, just enter 'check_everything -l' to open",
        "the link file."
    end
    # Assume no problems with the link file.
    @category_space, @category_dash = false, false

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
    
    # Check for errors; don't allow the user to see bad categories or open up
    # websites if the categories are not formatted properly.
    elsif @category_space
        puts "Your link file includes a category with a space in it; " +
          "please fix by entering 'check_everything -l' into your command line."
    elsif @category_dash
        puts "Your link file includes a category with a dash, which is " +
          "not allowed; please fix by entering 'check_everything -l' into your command line."

    # View the categories the user has defined.
    elsif @argv.any? {|arg| KNOWN_TAGS[:categories].include?(arg)}
      view_categories
    
    # Open up the websites!
    else
      open
    end
  end
  
  private
  def self.help
    puts "\n'check_everything' will open all sites labeled with the 'default' tag."
    puts
    puts "Available tags:"
    puts "   -h, --help           display the help message"
    puts "   -l, --links,         view/edit links and categories"
    puts "   -c, --categories     view the currently defined categories"
    puts "   -a, --all            open all websites"
    puts "   <tags>               open a specific site group"
    puts "                        (multiple are allowed, separated by spaces)"
    puts
    puts "Note: The first tag in this list will be the only tag evaluated."
    puts
  end

  def self.view_categories
    puts "You have currently defined the following categories:\n\n"
    @links.keys.sort.each {|key| puts "  #{key}"}
  end

  def self.open
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

  def self.read_file(file_name)
    file = File.open(file_name, "r")
    data = file.read
    file.close
    data
  end

  def self.extract_links
    link_file = read_file(LINKFILE).split("\n")
    cur_tags = []
    
    @links = {}
    link_file.each do |line|
      if line.start_with?("&&")
        # add tags as keys in @links, and assign to cur_tags
        cur_tags = add_category(line[2..-1].strip).flatten
      elsif line.start_with?("--")
        # add links to each relevant tag in @links
        cur_tags.each { |tag|
          @links[tag] << line[2..-1].strip
        }
      end
    end
  end

  # Recursive helper method for extract_links
  def self.add_category(line)
    line.downcase!
    # Add multiple tags, if separated by semicolons.
    if line.include?(";")
      line.split(";").map(&:strip).each do |tag|
        add_category(tag.strip)
      end
    else
      # Note to raise an error if there is an invalid category.
      @category_space = true if line.match(/ /)
      @category_dash = true if line.match(/-/)
      @links[line] ||= []
      [line]
    end
  end
end