require 'open-uri'
require 'nokogiri'

class CheckEverything
  KNOWN_TAGS = {
    :help => ['-h','--help'],
    :links => ['-l','--links'],
    :ruby => ['-r','--ruby'],
    :categories => ['-c', '--categories'],
    :all => ['-a', '--all']
  }
  LINKPATH = "#{File.expand_path('~')}/.check_everything_links"
  LINKFILE = "#{LINKPATH}/links.txt"
  RUBYFILE = "#{LINKPATH}/ruby.txt"
  SUB_CHARS = {
    '?' => '-3F-',
    '!' => '-21-',
    '|' => '-7C-',
    ']' => '-5D-',
    '[' => '-5B-',
    '=' => '-3D-',
    '+' => '-2B-',
    '-' => '-2D-',
    '*' => '-2A-',
    '/' => '-2F-',
    '%' => '-25-',
    '~' => '-7E-',
    '<' => '-3C-',
    '>' => '-3E-',
    '&' => '-26-',
    '@' => '-40-'
  }

  def self.run
    @argv = ARGV.map(&:downcase)
    until ARGV.empty?
      ARGV.pop
    end
    # Only assemble Ruby development library if requested to.
    @ruby_dev_assemble = false
    # Create a new link file if none has been created yet
    if !File.exists?(LINKFILE)
      # If a previous version created a file rather than a directory, move it into
      # the new directory.
      if File.exists?(LINKPATH)
        system("mv #{LINKPATH} #{LINKPATH}2")
        system("mkdir #{LINKPATH}")
        system("mv #{LINKPATH}2 #{LINKFILE}")
      else
        system("mkdir #{LINKPATH}")
        system("cp #{File.dirname(__FILE__)}/check_everything/links.txt #{LINKFILE}")
      end
      @argv = ["-l"]
      print "Are you a Ruby Dev who will want documentation-checking ",
        "functionality? [Y/n] "
      @ruby_dev_assemble = true unless gets.strip.downcase == 'n'
      puts "\nPlease customize your installation.",
        "This message will only be shown once.",
        "To open again and customize, just enter 'check_everything -l' to open",
        "the link file."
    end
    # Assume no problems with the link file.
    @category_space, @category_dash = false, false

    extract_links

    # First check for unknown arguments and print out a helpful message.
    known_tags = KNOWN_TAGS.values.flatten + @links.keys + @ruby_links
    unmatched_args = @argv.select do |arg|
      !known_tags.any? do |known_tag|
        known_tag.downcase == arg.split("#")[0]
      end
    end
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
      # If asked to build the Ruby Dev file, build it!
      assemble_ruby_docs_file if @ruby_dev_assemble

      system("open #{LINKFILE}")
    
    elsif @argv.any? {|arg| KNOWN_TAGS[:ruby].include?(arg)}
      assemble_ruby_docs_file

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
      open_links
    end
  end
  
  private
  def self.help
    puts "\n'check_everything' will open all sites labeled with the 'default' tag."
    puts
    puts "Available tags:"
    puts "   -h, --help           display the help message"
    puts "   -l, --links          view/edit links and categories"
    puts "   -r, --ruby           install Ruby Documentation functionality"
    puts "   -c, --categories     view the currently defined categories"
    puts "   -a, --all            open all websites (will override documentation lookup)"
    puts "   <categories>         open a specific site group"
    puts "                        (multiple are allowed, separated by spaces)"
    puts
    puts "Note: The first tag in this list will be the only tag evaluated."
    puts
  end

  def self.view_categories
    puts "You have currently defined the following categories:\n\n"
    @links.keys.sort.each {|key| puts "  #{key}"}
  end

  def self.assemble_ruby_docs_file
    ruby_doc = Nokogiri::HTML(open("http://ruby-doc.org/core/"))
    class_names = []
    ruby_doc.css("p.class a").each{|class_name| class_names << class_name.text}
    ruby_doc.css("p.module a").each{|module_name| class_names << module_name.text}
    class_names.map!{|class_name| class_name.gsub(/::/,"/")}

    system("touch #{File.dirname(__FILE__)}/ruby_doc")
    File.open("#{File.dirname(__FILE__)}/ruby_doc", 'w') { |f|
      f.print class_names.join("\n")
    }
    system("cp #{File.dirname(__FILE__)}/ruby_doc #{RUBYFILE}")
  end

  def self.open_links
    @argv << "default" if @argv.empty?
    
    # If -a or --all is specified, select all links.  Otherwise, select specified
    # links, or the default links if none are specified.
    if @argv.any?{|arg| KNOWN_TAGS[:all].include?(arg)}
      links = @links.values.flatten.uniq
    else
      # Get links for all recognized categories
      links = @argv.map{|category| @links[category]}.flatten.compact.uniq
      # If a Ruby class name has been specified, open documentation for that class.
      links.concat(add_documentation_to_links)
    end

    urls = links.map { |url|
      url.start_with?("http") ? url : url = "http://" << url
    }.join(" ")
    system("open #{urls}")

    puts "\nIt's been a pleasure serving up your websites!"
    puts "Did you know you can use categories to open specific site groups? " +
      "Enter 'check_everything --links' for details.\n" if ARGV.empty?
  end

  def self.add_documentation_to_links
    [].tap do |links|
      if File.exists?(RUBYFILE)
        classes = read_file(RUBYFILE).split
        
        # Allow arguments of the form "array" or "array#collect"
        class_argv = @argv.map {|arg| arg.split('#')}
        class_matches = classes.map { |class_name|
          class_argv.map { |name|
            # If a match is found, return an array with either 1 element (class)
            # or 2 elements (class and method)
            if class_name.downcase == name[0]
              [class_name, name[1]].compact
            end
          }.compact
        }.reject(&:empty?).flatten(1)
        
        # If matches were found, serve them up!
        if class_matches.size > 0
          class_matches.each do |klass|
            # Add a method name to the link only if one is specified.
            method = klass[1] ? "#method-i-#{klass[1]}" : ""
            method = method.gsub(/[#{SUB_CHARS.keys}\[\]]/,SUB_CHARS)
            method = method.gsub('--','-')
            method = method[0..-2] if method[-1] == '-'
            method = method[1..-1] if method[0] == '-'
            links << "ruby-doc.org/core-#{RUBY_VERSION}/#{klass[0]}.html#{method}"
          end
        end
      end
    end
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

    @ruby_links = []
    if File.exists?(RUBYFILE)
      classes = read_file(RUBYFILE).split
      classes.each {|class_name| @ruby_links << class_name}
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

CheckEverything.run