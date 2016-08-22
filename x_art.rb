# coding: utf-8
require 'watir'

# XArt scraper
class XArt
  attr_accessor :browser, :wait_time, :y_offset

  Info = Struct.new(:title, :date, :image, :skip)

  def initialize
    @wait_time = 10
    @y_offset = 0
    switches = %w(--user-data-dir=/Users/apple/Library/Application\ Support/Google/Chrome/)
    @browser = Watir::Browser.new :chrome, switches: switches
    @browser.goto 'http://www.x-art.com/updates/'
  end

  def wait_element(*args)
    start_time = Time.now
    while Time.now - start_time < @wait_time
      el = @browser.element(*args)
      sleep(0.01)
      return el if el.exist?
    end
    nil
  end

  def wait_element_visible(*args)
    loop do
      elem = wait_element(*args)
      return elem if elem.visible?
    end
  end

  def convert_date(date)
    strs = date.split(',')
    year = strs[1].to_i
    strs2 = strs[0].split(' ')
    month_str = strs2[0]
    day = strs2[1].to_i
    month_index = %w(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC).index(month_str)
    if month_index.nil?
      puts "Invalid month #{month_str}"
      month = 1
    else
      month = month_index + 1
    end
    format '%04d-%02d-%02d', year, month, day
  end

  # div 에서 각종 정보를 찾는다
  def find_info(div)
    return nil if div.wd.location.y < @y_offset

    header = div.div(class: 'item-header')
    header = div.div(class: 'columns') unless header.exist?
    return nil unless header.exist?

    img = div.img
    info = Info.new
    info.title = header.h1.text
    info.date = convert_date(header.h2s[1].text)
    info.image = img.src
    puts "#{info.title} #{info.image} #{info.date}"
    info
  end

  def find_infos
    infos = @browser.divs(class: 'item').map { |div| find_info div }
    infos.select { |info| !info.nil? }
  end

  def same_title_adjacent?(infos, i)
    (i - 1..0).each do |j|
      return true if infos[j].title == infos[i].title
    end
    (i + 1..infos.length - 1).each do |j|
      return true if infos[j].title == infos[i].title
    end
  end

  def mark_duplicate(infos)
    infos.each_with_index do |info, i|
      if same_title_adjacent?(infos, i) && info.image =~ %r{/videos/}
        info.skip = true
      end
    end
  end

  def find_unique_infos(old_infos)
    infos = find_infos
    if old_infos
      last_index = infos.find_index do |info|
        info.title == old_infos.last.title && info.image == old_infos.last.image
      end
      if last_index
        infos = infos[last_index + 1, infos.length]
      end
    end
    infos = mark_duplicate(infos)
    infos.select { |info| !info.skip }
  end

  def open_plex
    browser.execute_script 'window.open()'
    browser.windows.last.use
    browser.goto 'http://192.168.0.30:32400/web/index.html#'
  end

  def input_field_title(id_str, text)
    input_elem = wait_element(id: id_str)
    inp = input_elem.parent.div(class: 'selectize-input').text_field
    loop do
      break if inp.visible?
      sleep 0.1
    end
    inp.set(text, :return)
  end

  def input_field_date(id_str, date)
    inp = wait_element(id: id_str).to_subtype
    inp.set(date, :return)
  end

  def input_field_url(name, url)
    inp = wait_element(name: name).to_subtype
    inp.set(url, :return)
  end

  def enter(info)
    quick_search = wait_element(tag_name: 'input',
                                class: 'QuickSearchInput-searchInput-wnRxj')
    quick_search.to_subtype.set 'x-art ' + info.title

    candidate = wait_element(class: 'QuickSearchResult-button-xsMFe')
    return if candidate.nil?
    candidate.click

    edit_button = wait_element(class: 'edit-btn')
    return if edit_button.nil?
    edit_button.click

    input_field_title('lockable-title', '[X-Art] ' + info.title)
    input_field_title('lockable-titleSort', '[X-Art] ' + info.title)

    if info.date == '2015-09-31'
      info.date = '2015-09-30'
    end

    input_field_date('lockable-originallyAvailableAt', info.date)
    input_field_title('lockable-contentRating', 'X')
    input_field_title('lockable-studio', 'X-Art')

    poster_button = wait_element(class: 'poster-btn')
    poster_button.click

    upload_button = wait_element(class: 'upload-url-btn')
    upload_button.click

    input_field_url('url', info.image)

    @wait_time = 10
    wait_element_visible(class: 'upload-back-btn')

    @wait_time = 3
    save_button = wait_element(class: 'save-btn')
    save_button.click

    sleep 0.1 while save_button.exist? && save_button.visible?
  end

  def print(infos)
    infos.each do |info|
      puts "#{info.title} #{info.image} #{info.date}"
    end
  end

  def last_item_info
    infos = find_infos
    infos.last
    # items = @browser.divs(class: 'item')
    # (items.length - 1..0).each do |item|
    #   info = find_info(item)
    #   return info if !info.nil?
    # end
  end

  def next_page
    # info = last_item_info
    # puts info.title

    @browser.send_keys(:page_down)
    sleep 3
    @y_offset = @browser.execute_script 'return window.pageYOffset;'

    # while last_item_info == info do
    #   puts last_item_info.title
    #   sleep 0.5
    # end
  end

  def scrape
    old_infos = nil
    empty_count = 0
    while empty_count < 3
      infos = find_unique_infos(old_infos)

      open_plex

      if infos.empty?
        empty_count += 1
      else
        empty_count = 0

        infos.each do |info|
          enter(info)
        end
        @browser.windows.last.close

        old_infos = infos
      end

      next_page
      puts '------------------------------'
    end
  end
end
