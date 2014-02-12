require 'pry'
require 'awesome_print'

class WebOpener
  KNOWN_TAGS = {
    :help => ['-h','--help'],
    :tags => ['-t','--tags', '-l','--links'],
    :all => ['-a', '--all']
  }

  def run
    ARGV.map(&:downcase)
    
    # First check for unknown arguments and print out a helpful message.
    unmatched_args = ARGV.select{ |arg| !KNOWN_TAGS.values.flatten.include?(arg)}
    if !unmatched_args.empty?
      puts "\nUnknown option#{ARGV.size > 1 ? "s" : nil}: " +
        "#{unmatched_args.join(" ")}"
      puts "usage: check_everything [-h] [--help] [-t] [--tags] [-l] [--links] [<tags>]"
      puts
    
    # Print out a help message.
    elsif ARGV.any? {|arg| KNOWN_TAGS[:help].include?(arg.downcase)}
      help

    # Edit the tags and links.
    elsif ARGV.any? {|arg| KNOWN_TAGS[:tags].include?(arg.downcase)}
      system("open links.txt")
    
    # Open up the websites!
    else
      extract_links
      open
    end
  end

  def test_open
    open
  end

  private
  def help
    puts "\n'check_everything' will open all sites."
    puts
    puts "Available tags:"
    puts "   -h, --help                 display the help message"
    puts "   -t, -l, --tags, --links    view/edit links and tags"
    puts "   <tags>                     open a specific site group"
    puts
  end

  def open
    @links.each {|link| system("open #{link}")}

    puts "It's been a pleasure serving you your favorite websites!"
    puts "Did you know you can use tags to serve specific site groups? " +
      "Type 'check_everything help' for details." if ARGV.empty?
  end

  def read_file(file_name)
    file = File.open(file_name, "r")
    data = file.read
    file.close
    data
  end

  def extract_links
    link_file = read_file('links.txt').split("\n")
    cur_tags = []
    
    @links = {}
    link_file.each do |line|
      if line.start_with?("&&")
        # add tags as keys in @links, and assign to cur_tags
        cur_tags = add_tag(line[2..-1].strip).flatten
      elsif line.start_with?("--")
        # add links to each relevant tag in @links
        cur_tags.each { |tag|
          @links[tag] << line[2..-1]
        }
      end
    end
  end

  # Helpful recursive method for extract_links
  def add_tag(line)
    line.downcase!
    # Add multiple tags, if separated by semicolons.
    if line.include?(";")
      line.split(";").map(&:strip).each do |tag|
        add_tag(tag.strip)
      end
    else
      @links[line] ||= []
      tag_space_message = "You have a tag with a space in it; please fix by entering" +
        "'check_everything -t' into your command line."
      raise tag_space_message if line.match(/ /)
      [line]
    end
  end

end

ap WebOpener.new.run