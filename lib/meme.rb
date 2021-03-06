require 'net/http'
require 'rubygems'
require 'nokogiri'
require 'cgi'

##
# Generate memes using http://memegenerator.net

class Meme

  ##
  # Sometimes your meme will have an error, fix it!

  class Error < RuntimeError; end

  ##
  # Every meme generator needs a version

  VERSION = '1.6'

  ##
  # For statistics!

  USER_AGENT = "meme/#{VERSION} Ruby/#{RUBY_VERSION}"

  ##
  # We have some generators up-in-here

  GENERATORS = Hash.new do |_, k|
    raise Error, "unknown generator #{k}"
  end

  # keep generators in alphabetical order

  GENERATORS['ANTEATER']          = [41191,  'anteater']
  GENERATORS['A_DODSON']          = [106375, 'Antoine-Dodson']
  GENERATORS['A_DOG']             = [940,    'Advice-Dog']
  GENERATORS['A_FATHER']          = [1436,   'High-Expectations-Asian-Father']
  GENERATORS['BUTTHURT_DWELLER']  = [1438,   'Butthurt-Dweller']
  GENERATORS['B_FROG']            = [1211,   'Foul-Bachelorette-Frog']
  GENERATORS['B_FROG2']           = [1045,   'Foul-Bachelor-Frog']
  GENERATORS['COOL_STORY_HOUSE']  = [16948,  'cool-story-bro-house']
  GENERATORS['CREEPER']           = [173501, 'Minecraft-Creeper']
  GENERATORS['C_WOLF']            = [931,    'Courage-Wolf']
  GENERATORS['F_FRY']             = [84688,  'Futurama-Fry']
  GENERATORS['G_GRANDPA']         = [185650, 'Grumpy-Grandpa']
  GENERATORS['H_MERMAID']         = [405224, 'Hipster-Mermaid']
  GENERATORS['I_DONT_ALWAYS']     = [38926,  'The-Most-Interesting-Man-in-the-World']
  GENERATORS['I_WOLF']            = [926,    'Insanity-Wolf']
  GENERATORS['INCEPTION']         = [107949, 'Inception']
  GENERATORS['J_DUCREUX']         = [1356,   'Joseph-Ducreux']
  GENERATORS['KEANU']             = [47718,  'Keanu-reeves']
  GENERATORS['MINECRAFT']         = [122309, 'Minecraft']
  GENERATORS['O-RLY-OWL']         = [117041, 'O-RLY-OWL', 'ORLY???']
  GENERATORS['OBAMA']             = [1332,   'Obama-']
  GENERATORS['PHILOSORAPTOR']     = [984,    'Philosoraptor']
  GENERATORS['P_OAK']             = [24321,  'Professor-Oak']
  GENERATORS['SCUMBAG']           = [364688, 'Scumbag-Steve']
  GENERATORS['SPARTA']            = [1013,   'sparta']
  GENERATORS['SPIDERMAN']         = [1037,   'Question-Spiderman']
  GENERATORS['SWEDISH_CHEF']      = [186651, 'Swedish-Chef']
  GENERATORS['S_AWKWARD_PENGUIN'] = [983,    'Socially-Awkward-Penguin']
  GENERATORS['TOWNCRIER']         = [434537, 'Towncrier']
  GENERATORS['TROLLFACE']         = [1030,   'Troll-Face']
  GENERATORS['UNICORN_BOY']       = [57022,  'unicorn-boy']
  GENERATORS['US_POINT']          = [131083, 'Uncle-Sam-Point', 'I WANT YOU']
  GENERATORS['V_BABY']            = [11140,  'Victory-Baby']
  GENERATORS['XZIBIT']            = [3114,   'XZIBIT']
  GENERATORS['Y_U_NO']            = [165241, 'Y-U-NO', 'Y U NO']

  # keep generators in alphabetical order

  ##
  # Looks up generator name

  def GENERATORS.match(name)
    # TODO  meme Y U NO DEMETAPHONE?
    return self[name] if has_key? name
    matcher = Regexp.new(name, Regexp::IGNORECASE)
    _, generator = find { |k,v| matcher =~ k || v.grep(matcher).any? }
    generator || self[name] # raises the error if generator is nil
  end

  ##
  # Interface for the executable

  def self.run argv = ARGV
    generator = ARGV.shift

    if generator == '--list' then
      width = GENERATORS.keys.map { |command| command.length }.max

      GENERATORS.sort.each do |command, (id, name, _)|
        puts "%-*s  %s" % [width, command, name]
      end

      exit
    end

    abort "#{$0} [GENERATOR|--list] LINE [ADDITONAL_LINES]" if ARGV.empty?

    meme = new generator
    link = meme.generate *ARGV

    meme.paste link

    if $stdout.tty?
      puts link
    else
      puts meme.fetch link
    end
    link
  rescue Interrupt
    exit
  rescue SystemExit
    raise
  rescue Exception => e
    abort "ERROR: #{e.message} (#{e.class})"
  end

  ##
  # Generates links for +generator+

  def initialize generator
    @template_id, @generator_name, @default_line = GENERATORS.match generator
  end

  ##
  # Generates a meme with +line1+ and +line2+.  For some generators you only
  # have to supply one line because the first line is defaulted for you.
  # Isn't that great?

  def generate *args
    url = URI.parse 'http://memegenerator.net/Instance/CreateOrEdit'
    res = nil
    location = nil

    # Put the default line in front unless theres more than 1 text input.
    args.unshift(@default_line) unless args.size > 1

    raise Error, "two lines are required for #{@generator_name}" unless args.size > 1

    post_data = { 'templateType'  => 'AdviceDogSpinoff',
                  'templateID'    => @template_id,
                  'generatorName' => @generator_name }

    # go through each argument and add it back into the post data as textN
    (0..args.size).map {|num| post_data.merge! "text#{num}" => args[num] }

    Net::HTTP.start url.host do |http|
      post = Net::HTTP::Post.new url.path
      post['User-Agent'] = USER_AGENT
      post.set_form_data post_data

      res = http.request post

      location = res['Location']
      redirect = url + location

      get = Net::HTTP::Get.new redirect.request_uri
      get['User-Agent'] = USER_AGENT

      res = http.request get
    end

    doc = Nokogiri.HTML res.body
    doc.css("a[href=\"#{location}\"] img").first['src']
  end

  def fetch link
    url = URI.parse link
    res = nil

    Net::HTTP.start url.host do |http|
      get = Net::HTTP::Get.new url.request_uri
      get['User-Agent'] = USER_AGENT

      res = http.request get
    end
    res.body
  end

  ##
  # Tries to find clipboard copy executable and if found puts +link+ in your
  # clipboard.

  def paste link
    clipboard = %w{
      /usr/bin/pbcopy
      /usr/bin/xclip
    }.find { |path| File.exist? path }

    if clipboard
      IO.popen clipboard, 'w' do |io| io.write link end
    end
  end

end

