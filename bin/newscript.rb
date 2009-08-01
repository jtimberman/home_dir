#!/usr/bin/ruby -w
# Author: Joshua Timberman <joshua@opscode.com>
#

interpreters = {
  'rb' => '/usr/bin/ruby -w',
  'py' => '/usr/bin/python',
  'pl' => '/usr/bin/perl -w',
  'sh' => '/bin/bash',
}

path = ARGV[0]
lang = ARGV[1] ? ARGV[1] : interpreters[File.basename(path).split('.').last]
edit = ARGV[2] ? ARGV[2] : ENV['EDITOR']

fail "Specify filename to create" unless path

unless File.exists?(path)
    File.open(path, "w") { |f| f.puts "#!#{lang}" } 
end

File.chmod(0755, path)
system edit, path
