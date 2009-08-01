# Author: Joshua Timberman <joshua@opscode.com>
#
require 'tempfile'

PROJECTS = "#{ENV['HOME']}/projects"

dirs  = %w[ bin etc ]
files = %w[
  .bash*
  .gemrc
  .irbrc
  Capfile
  Rakefile
]

desc "By default, display a message and exit."
task :default do
  puts "Select a rake method."
end

desc "Install configuration in the user HOME directory."
task :install do
  dirs.each do |d|
    sh("tar -cpf - #{d} | (cd  #{ENV['HOME']} && tar -xpf -)")
  end
  files.each do |f|
    sh("cp #{f} #{ENV['HOME']}")
  end
end

