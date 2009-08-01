#!/usr/bin/ruby

require 'yaml'
require 'resolv'

def find_servers(key, value)  
  case value
  when Array
    value.each do |v|
      @servers[v] = true
    end
  when String
    value.each do |v|
      @servers[v] = true
    end
  end
end

def link_name(server)
  (host, port) = server.split(":")
  ip = Resolv.getaddress(host).gsub("\.", "_")
  link = "#{ip}_#{port}"
  link
end

# from template: plugin_config, plugin_dir
# File.symlink("/usr/share/munin/plugins/#{memc}", 
#   "/etc/munin/plugins/#{ip}_#{port}")
def make_links(server)
  plugin_dir = "/usr/share/munin/plugins"
  plugin_conf = "/etc/munin/plugins"
  Dir.foreach(plugin_dir) do |file| 
    if file =~ /memcached_\w+$/  
      File.symlink("#{plugin_dir}/#{file}", "#{plugin_conf}/#{file}#{link_name(server)}")
    end
  end
end

@servers = Hash.new

outfile = File.new("/tmp/out_config.yml", "w")

File.open(ARGV[0]).each do |line|
  outfile.puts line unless line =~ /\<\%|\%\>/
end

outfile.close

infile = File.open("/tmp/out_config.yml")

config_hash = YAML.load(infile)

infile.close
File.delete("/tmp/out_config.yml")

config_hash.each do |top, next_hash|
  if top == 'production' 
    next_hash.each do |key, value|
      find_servers(key, value) if key =~ /memcache_servers$/
    end
  end
end

@servers.each_key do |server|
  server.each do |s| 
    make_links(s)
  end
end
