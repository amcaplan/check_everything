require 'open-uri'
require 'nokogiri'

class CheckEverything
  KNOWN_FLAGS = {
    :help => {
      :position => 1,
      :flags => ['-h','--help'],
      :description => 'display the help message'
    },
    :links => {
      :position => 2,
      :flags => ['-l','--links'],
      :description => 'view/edit links and categories'
    },
    :ruby => {
      :position => 3,
      :flags => ['-r','--ruby'],
      :description => 'install Ruby Documentation functionality'
    },
    :categories => {
      :position => 4,
      :flags => ['-c', '--categories'],
      :description => 'view the currently defined categories'
    },
    :all => {
      :position => 5,
      :flags => ['-a', '--all'],
      :description => 'open all websites (will override documentation lookup)'
    }
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
    ARGV.clear # prevent ARGV from interfering with "gets" input.

    # Run first-time options if check_everything hasn't been run yet.
    customize_installation if !File.exists?(LINKFILE)

    extract_links

    # First check for unknown arguments and print out a helpful message.
    unmatched_args = unknown_arguments
    if !unmatched_args.empty?
      puts_unmatched_error_message(unmatched_args)
    
    # Respond to flags.
    elsif argv_requests?(:help)
      help
    elsif argv_requests?(:links)
      system("open #{LINKFILE}")
    elsif argv_requests?(:ruby)
      assemble_ruby_docs_file
    
    # Block execution of final options if an invalid character exists
    # in the user's link file.
    elsif @invalid_char_in_links
        puts "Your link file includes a category with a " +
          "\"#{@invalid_char_in_links}\" character in it; please fix by " +
          "entering 'check_everything -l' into your command line."
    elsif argv_requests?(:categories)
      view_categories
    # If there are no flags, open the websites!
    else
      open_links
    end
  end
  
  private

  def self.known_flags
    KNOWN_FLAGS.values.map{|command| command[:flags]}.flatten
  end

  def self.customize_installation
    # If a previous version created a file rather than a directory, move it into
    # the new directory.
    if File.exists?(LINKPATH)
      system("mv #{LINKPATH} #{LINKPATH}99999999")
      system("mkdir #{LINKPATH}")
      system("mv #{LINKPATH}99999999 #{LINKFILE}")
    else
      system("mkdir #{LINKPATH}")
      system("cp #{File.dirname(__FILE__)}/check_everything/links.txt #{LINKFILE}")
    end

    # On first run, prompt to customize the installation.
    @argv = ["-l"]
    print "Greetings, new user!  You're almost ready to use check_everything!"
    print "Are you a Ruby Dev who will want documentation-checking ",
      "functionality? [Y/n] "
    assemble_ruby_docs_file unless gets.strip.downcase == 'n'
    puts "\nPlease customize your installation.",
      "This message will only be shown once.",
      "To open again and customize, just enter 'check_everything -l' to open",
      "the link file."
    puts "You may now use check_everything normally."
  end

  def self.unknown_arguments
    all_known_flags = known_flags + @links.keys + @ruby_links
    @argv.select do |arg|
      all_known_flags.none? do |known_flag|
        known_flag.downcase == arg.split(/#|::/)[0]
      end
    end
  end

  def self.puts_unmatched_error_message(unmatched_args)
    puts "\nUnknown option#{@argv.size > 1 ? "s" : nil}: " +
        "#{unmatched_args.join(" ")}"
    print "usage: check_everything"
    known_flags.each {|flag| print " [#{flag}]"}
    puts "\n\nHint: Enter 'check_everything --help' to see the options!"
    puts "\n"
  end

  def self.argv_requests?(command)
    @argv.any? {|arg| KNOWN_FLAGS[command][:flags].include?(arg)}
  end

  def self.help
    puts "\n'check_everything' without flags will open all sites labeled " +
      "with the 'default' category."
    puts
    puts "Available flags:"
    sorted_flags = KNOWN_FLAGS.sort_by{|command, details| details[:position]}
    sorted_flags.each do |command, details|
      puts "   #{details[:flags].join(", ").ljust(21)}#{details[:description]}"
    end
    puts "   #{"<categories>".ljust(21)}open a specific site group"
    puts "                        (multiple are allowed, separated by spaces)"
    puts "\nNote: The first flag in this list will be the only flag evaluated."
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
    
    if argv_requests?(:all)
      links = @links.values.flatten.uniq
    else
      # Get links for all recognized categories
      links = @argv.map{|category| @links[category]}.flatten.compact.uniq
      # If a Ruby class name has been specified, open documentation for that class.
      links.concat(add_documentation_to_links)
    end

    # Reject any empty strings ("--      " in the link file)
    links.reject!{|link| link.strip.empty?}
    links = add_http(links)
    launch(links)
  end

  def self.add_http(links)
    links.map { |url|
      url.start_with?("http") ? "\"#{url}\"" : url = "\"#{"http://" << url}\""
    }.join(" ")
  end

  def self.launch(urls)
    if !urls.empty?
      system("open #{urls}")

      puts "\nIt's been a pleasure serving up your websites!"
      puts "Did you know you can use categories to open specific site groups? " +
      "Enter 'check_everything --links' for details.\n" if ARGV.empty?
    else
      puts "You don't seem to have any links for \"#{@argv.join("\" or \"")}\" in " +
        "your file.  Enter `check_everything -l` into your command line to " +
        "add some links!"
    end
  end

  def self.add_documentation_to_links
    [].tap do |doc_links|
      if File.exists?(RUBYFILE)
        classes = read_file(RUBYFILE).split
        
        # Allow arguments of the form "array" or "array#collect" or "array::new"
        class_argv = @argv.map {|arg| arg.split(/#|:/)}
        class_matches = classes.map { |class_name|
          class_argv.map { |name|
            # If a match is found, return an array with either 1 element (class) or
            # 2 elements (class, instance method) or 3 elements (class, "", class method)
            [class_name, name[1], name[2]] if class_name.downcase == name[0]
          }.compact
        }.reject(&:empty?).flatten(1)
        
        # If matches were found, serve them up!
        class_matches.each do |klass|
          # Add a method name to the link only if one is specified.
          method = if klass[2]
              # For class methods, use the class method link format.
              "#method-c-#{klass[2]}"
            elsif klass[1]
              # For instance methods, use the instance method link format.
              "#method-i-#{klass[1]}"
            else
              ""
            end
          # Create link path and remove extra dashes added
          # in the process of replacing special characters.
          method = method.gsub(/[#{SUB_CHARS.keys}\[\]]/,SUB_CHARS).gsub('--','-')
          method = method[0..-2] if method[-1] == '-'
          doc_links << "ruby-doc.org/core-#{RUBY_VERSION}/#{klass[0]}.html#{method}"
        end
      end
    end
  end

  def self.extract_links
    extract_links_from(read_file(LINKFILE).split("\n"))
    extract_ruby_links
  end

  def self.extract_links_from(link_file)
    current_categories = []
    @links = {}
    link_file.each do |line|
      case line[0,2]
      when "&&"
        # add categories as keys in @links, and assign to current categories
        current_categories = add_category(line[2..-1].strip)
      when "--"
        # add links to each relevant categories in @links
        current_categories.each { |category|
          @links[category] << line[2..-1].strip
        }
      end
    end
  end

  def self.add_category(line)
    line.downcase!
    # Add multiple categories, if separated by semicolons.
    if line.include?(";")
      line.split(";").map(&:strip).each do |category|
        add_category(category.strip)
      end
    else
      # Note to raise an error if there is an invalid category.
      invalid_char = line.match(/[ \-#:\/]/)
      if invalid_char
        @invalid_char_in_links = invalid_char.to_a[0] if invalid_char
      end
      # Optionally instantiate an array for the category if it doesn't exist yet.
      @links[line] ||= []
      [line]
    end
  end

  def self.extract_ruby_links
    @ruby_links = []
    if File.exists?(RUBYFILE)
      classes = read_file(RUBYFILE).split
      classes.each {|class_name| @ruby_links << class_name}
    end
  end

  def self.read_file(file_name)
    file = File.open(file_name, "r")
    data = file.read
    file.close
    data
  end
end