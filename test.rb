require './x_art'

xart = XArt.new
# browser = Watir::Browser.new :chrome
# browser.goto 'http://www.x-art.com/updates/'
# browser.text_field(name: 'q').set("WebDriver rocks!")
# browser.button(name: 'btnG').click
# puts browser.url
# browser.wait(60)
xart.scrape

# browser.send_keys :command, 't'
# browser2 = Watir::Browser.new :chrome

puts 'Enter to quit: '
gets
