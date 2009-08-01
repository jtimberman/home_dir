# Author: Joshua Timberman <joshua@opscode.com>
#
set(:nodelist) do
  Capistrano::CLI.ui.ask "Node list: "
end unless exists?(:nodelist)

nodelist.split.each do |node|
  role :nodes, node
end

if ENV.has_key?("HOMEDIR")
  set(:home, ENV["HOMEDIR"])
  set(:user, ENV["USER"])
else
  set(:home, '/home/jtimberman')
  set(:user, 'jtimberman')
end

local_home = "/Users/jtimberman" unless exists?(:local_home)

desc "Push public half of SSH key to target hosts."
task :ssh_key do
  ssh_dir    = "#{home}/.ssh"
  local_key  = "#{local_home}/.ssh/id_rsa.pub"
  remote_key = "#{ssh_dir}/authorized_keys"
  dir_perms  = "700"
  file_perms = "600"

  run "mkdir -p #{ssh_dir}"
  run "touch #{ssh_dir}/known_hosts"
  run "chmod #{dir_perms} #{ssh_dir}"
  upload "#{local_key}", "#{remote_key}", :mode => "600"
end

desc "Push my bash profile to target hosts."
task :bashrc do 
  profile = ".bashrc"
  run "echo > .bash_logout"
  upload "#{local_home}/#{profile}", "#{home}/#{profile}", :via => :scp
  run "rm ~/.bash_logout"
end

desc "Push my gem config to target hosts."
task :gemrc do 
  file = ".gemrc"
  upload "#{local_home}/#{file}", "#{home}/#{file}", :via => :scp
end

desc "Specify -S nodelist='node1 node2 ...'"
task :default do
  ssh_key
  bashrc
  gemrc
end

