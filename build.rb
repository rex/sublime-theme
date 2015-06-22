#!/usr/bin/env ruby

require 'optparse'
require 'json'
require 'plist'
require 'listen'

class Hash
  def symbolize_keys
    symbolized_hash = Hash.new
    self.each { |k, v| symbolized_hash[k.to_sym] = v }

    symbolized_hash
  end
end

class ThemeBuilder
  attr_reader :scopes

  def initialize(params)
    log "Initializing ThemeBuilder"
    log params

    @config_path = params[:config_path]
    @current_dir = File.dirname(__FILE__)
    @src_dir = "#{@current_dir}/#{params[:source_directory]}"
    @debug = params[:debug]
  end

  def log(message)
    p " > #{message}" if @debug
  end

  def build
    @meta = {}
    @scopes = []

    read_config

    source_files.each do |file|
      process_file(file)
    end

    save_theme
  end

  def source_files
    glob_string = "#{@src_dir}/**/*.json"
    Dir.glob(glob_string)
  end

  def read_source_file(path)
    JSON.parse( replace_colors( File.read(path) ) ).symbolize_keys
  end

  def read_config
    @config = JSON.parse( File.read(@config_path) ).symbolize_keys
    @colors = @config[:colors]
  end

  def process_file(path)
    contents = read_source_file(path)
    @scopes.concat(contents[:settings])
    @meta[:author] = contents[:author] if contents[:author]
    @meta[:colorSpaceName] = contents[:colorSpaceName] if contents[:colorSpaceName]
    @meta[:gutterSettings] = contents[:gutterSettings] if contents[:gutterSettings]
    @meta[:uuid] = contents[:uuid] if contents[:uuid]
    @meta[:name] = contents[:name] if contents[:name]
    @meta[:semanticClass] = contents[:semanticClass] if contents[:semanticClass]
  end

  def replace_colors(body)
    ret = body
    @colors.each_pair do |color_key, color_value|
      ret = ret.gsub("{{ #{color_key} }}", color_value)
    end

    ret
  end

  def save_theme
    log "Saving theme #{@config[:outfile]}"

    theme_data = {
      author: @meta[:author],
      colorSpaceName: @meta[:colorSpaceName],
      gutterSettings: @meta[:gutterSettings],
      uuid: @meta[:uuid],
      name: @meta[:name],
      semanticClass: @meta[:semanticClass],
      settings: @scopes
    }

    write_outfile(theme_data)
  end

  def write_outfile(theme_data)
    File.open(@config[:outfile], 'w') {|file| file.write(theme_data.to_plist)}
  end
end

options = {
  watch: false,
  config_path: 'builder-config.json',
  source_directory: 'src',
  debug: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: build.rb [options]"

  opts.on("-w", "--watch", "Watch for changes and recompile when changes are detected") do |v|
    options[:watch] = true
  end

  opts.on("--config [PATH]", "Specify path to builder configuration file") do |v|
    options[:config_path] = v unless v.nil?
  end

  opts.on("--source [PATH]", "Specify path to theme source files") do |v|
    options[:source_directory] = v unless v.nil?
  end

  opts.on("-v", "--verbose", "Verbose log output") do |v|
    options[:debug] = true
  end
end.parse!

puts " >> ThemeBuilder Options: #{options.inspect}"

builder = ThemeBuilder.new(options)

builder.build

if options[:watch]
  puts "Listening for changes in #{options[:source_directory]}..."
  listener = Listen.to(options[:source_directory]) do |modified, added, removed|
    puts " > modified: #{modified}" unless modified.empty?
    puts " > added: #{added}" unless added.empty?
    puts " > removed: #{removed}" unless removed.empty?

    builder.build
  end

  listener.start
  sleep
end
