#!/usr/bin/env ruby

# Downloaded from http://gist.github.com/100837
# Original author: Joshua Sierles (joshua@37signals.com)

require 'rubygems'
require 'thor'
require 'chef'
require 'chef/node'
require 'chef/rest'

# Please see the readme for overview documentation.
#
class JsonPrinter
  attr_reader :buf, :indent
  
  # ==== Arguments
  # obj<Object>::
  #   The object to be rendered into JSON.  This object and all of its 
  #   associated objects must be either nil, true, false, a String, a Symbol,
  #   a Numeric, an Array, or a Hash.
  #
  # ==== Returns
  # <String>::
  #   The pretty-printed JSON ecoding of the given <i>obj</i>.  This string
  #   can be parsed by any compliant JSON parser without modification.
  #
  # ==== Examples
  # See <tt>JsonPrinter</tt> docs.
  #
  def self.render(obj)
    new(obj).buf
  end
  
  
  private
  
  # Execute the JSON rendering of <i>obj</i>, storing the result in the 
  # <tt>buf</tt>.
  #
  def initialize(obj)
    @buf = ""
    @indent = ""
    render(obj)
  end
  
  # Increase the indentation level.
  #
  def indent_out
    @indent << " "
  end
  
  # Decrease the indendation level.
  #
  def indent_in
    @indent.slice!(-1, 1)
  end
  
  # Append the given <i>str</i> to the <tt>buf</tt>.
  #
  def print(str)
    @buf << str
  end
  
  # Recursive rendering method.  Primitive values, like nil, true, false, 
  # numbers, symbols, and strings are converted to JSON and appended to the
  # buffer.  Enumerables are treated specially to generate pretty whitespace.
  #
  def render(obj)
    # We can't use a case statement here becuase "when Hash" doesn't work for
    # ActiveSupport::OrderedHash - respond_to?(:values) is a more reliable
    # indicator of hash-like behavior.
    if NilClass === obj
      print("null")
      
    elsif TrueClass === obj
      print("true")
    
    elsif FalseClass === obj
      print("false")
    
    elsif String === obj
      print(escape_json_string(obj))
      
    elsif Symbol === obj
      print("\"#{obj}\"")
      
    elsif Numeric === obj
      print(obj.to_s)
    
    elsif Time === obj
      print(obj.to_s)
    
    elsif obj.respond_to?(:keys)
      print("{")
      indent_out
      last_key = obj.keys.last
      obj.each do |(key, val)|
        render(key)
        case val
        when Hash, Array
          indent_out
          print(":\n#{indent}")
          render(val)
          indent_in
        else
          print(": ")
          render(val)
        end
        print(",\n#{indent}") unless key == last_key
      end
      indent_in
      print("}")
      
    elsif Array === obj
      print("[")
      indent_out
      last_index = obj.size - 1
      obj.each_with_index do |elem, index|
        render(elem)
        print(",\n#{indent}") unless index == last_index
      end
      indent_in
      print("]")
      
    else
      raise "unrenderable object: #{obj.inspect}"
    end
  end
  
  # Special JSON character escape cases.
  ESCAPED_CHARS = {
    "\010" =>  '\b',
    "\f"   =>  '\f',
    "\n"   =>  '\n',
    "\r"   =>  '\r',
    "\t"   =>  '\t',
    '"'    =>  '\"',
    '\\'   =>  '\\\\',
    '>'    =>  '\u003E',
    '<'    =>  '\u003C',
    '&'    =>  '\u0026'}
  
  # String#to_json extracted from ActiveSupport, using interpolation for speed.
  #
  def escape_json_string(str)
    "\"#{
    str.gsub(/[\010\f\n\r\t"\\><&]/) { |s| ESCAPED_CHARS[s] }.
        gsub(/([\xC0-\xDF][\x80-\xBF]|
               [\xE0-\xEF][\x80-\xBF]{2}|
               [\xF0-\xF7][\x80-\xBF]{3})+/nx) do |s|
          s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/, '\\\\u\&')
        end
    }\""
  end
end

Chef::Config.from_file("/etc/chef/server.rb")

API_USERNAME=ENV['CHEF_USERNAME']
API_PASSWORD=ENV['CHEF_PASSWORD']

raise StandardError, "Please set CHEF_USERNAME and CHEF_PASSWORD" unless ENV['CHEF_USERNAME'] && ENV['CHEF_PASSWORD']

class Knife < Thor

  desc "register", "Register an openid for an API user"
  method_options :username => :required, :password => :required
  def register
    @rest = Chef::REST.new(Chef::Config[:registration_url])
    @rest.register(options[:username], options[:password])
  end
  
  
  desc "add_recipe", "Add a recipe to a node"
  method_options :recipe => :required, :after => :optional, :node => :required
  def add_recipe
    authenticate
    node = @rest.get_rest("nodes/#{expand_node(options[:node])}")
    node.recipes << options[:recipe] if !node.recipes.include?(options[:recipe])
    @rest.put_rest("nodes/#{expand_node(options[:node])}", node)
    list_recipes
  end

  desc "remove_recipe", "Remove a recipe from a node"
  method_options :recipe => :required, :node => :required
  def remove_recipe
    authenticate
    node = @rest.get_rest("nodes/#{expand_node(options[:node])}")
    node.recipes.delete(options[:recipe]) if node.recipes.include?(options[:recipe])
    @rest.put_rest("nodes/#{expand_node(options[:node])}", node)
    list_recipes
  end

  desc "show_attr", "Display a node attribute"
  method_options :node => :required, :attr => :required
  def show_attr
    authenticate
    node = @rest.get_rest("nodes/#{expand_node(options[:node])}")
    puts JsonPrinter.render(node[options[:attr]])
  end

  desc "edit_attr", "Display a node attribute"
  method_options :node => :required, :attr => :required
  def edit_attr
    editor = ENV['EDITOR'] || "vi"
    puts "Authenticating..."
    authenticate
    puts "Fetching node data for #{expand_node(options[:node])}..."
    node = @rest.get_rest("nodes/#{expand_node(options[:node])}")
    filename = "/tmp/.chef-#{node[:hostname]}"
    File.open(filename, "w") {|f| f.write(JsonPrinter.render(node[options[:attr]])) }
    system("#{editor} #{filename}") or raise StandardError, "Error communicating with #{editor}"
    node[options[:attr]] = JSON.parse(File.read(filename))
    puts "Storing node data for #{expand_node(options[:node])}..."
    begin
      retries = 5
      @rest.put_rest("nodes/#{expand_node(options[:node])}", node)    
    rescue Net::HTTPFatalError 
      retry if (retries -= 1) > 0
    end
    puts "Done."
  end
  
  desc "list_recipes", "List a node's recipes"
  method_options :node => :required
  def list_recipes
    authenticate
    node = @rest.get_rest("nodes/#{expand_node(options[:node])}")
    puts node.recipes.inspect
  end

  def authenticate
    @rest = Chef::REST.new(Chef::Config[:registration_url])
    @rest.authenticate(API_USERNAME, API_PASSWORD)
  end
end

  def expand_node(name)
    name + "_" + (ENV['CHEF_DOMAIN'] || `hostname -d`.chomp.gsub(".", "_"))
  end
  
Knife.start

