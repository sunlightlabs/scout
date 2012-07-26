set :environment, (ENV['target'] || 'staging')

if environment == 'production'
  set :user, 'scout'
  set :domain, 'ec2-184-73-3-156.compute-1.amazonaws.com'
  set :branch, 'master'
else
  set :user, 'alarms'
  set :domain, 'ec2-50-16-84-118.compute-1.amazonaws.com'
  set :branch, 'master'
end


# RVM stuff - not sure how/why this works, awesome
set :rvm_ruby_string, '1.9.3-p194@scout' 
# rvm-capistrano gem must be installed outside of the bundle
require 'rvm/capistrano'


set :application, user
set :sock, "#{user}.sock"

set :deploy_to, "/projects/#{user}/"


set :scm, :git
set :repository, "git@github.com:sunlightlabs/scout.git"

set :deploy_via, :remote_cache
set :runner, user
set :admin_runner, runner

role :app, domain
role :web, domain

set :use_sudo, false
after "deploy:update_code", "deploy:shared_links"
after "deploy:update_code", "deploy:bundle_install"
after "deploy:update_code", "deploy:create_indexes"
after "deploy", "deploy:set_crontab"
after "deploy", "deploy:cleanup"

namespace :deploy do
  task :start do
    # run "echo `which unicorn`"
    run "cd #{current_path} && unicorn -D -l #{shared_path}/#{sock} -c #{current_path}/unicorn.rb"
  end
  
  task :stop do
    run "kill `cat #{shared_path}/unicorn.pid`"
  end
  
  task :migrate do; end
  
  desc "Restart the server"
  task :restart, :roles => :app, :except => {:no_release => true} do
    run "kill -HUP `cat #{shared_path}/unicorn.pid`"
  end
  
  desc "Create indexes"
  task :create_indexes, :roles => :app, :except => {:no_release => true} do
    run "cd #{release_path} && rake create_indexes"
  end
  
  desc "Run bundle install --local"
  task :bundle_install, :roles => :app, :except => {:no_release => true} do
    run "cd #{release_path} && bundle install --local"
  end

  # current_path is correct here because this happens after deploy, not after deploy:update_code
  desc "Load the crontasks"
  task :set_crontab, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && rake set_crontab environment=#{environment} current_path=#{current_path}"
  end

  desc "Stop the crontasks"
  task :disable_crontab, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && rake disable_crontab"
  end
  
  desc "Get shared files into position"
  task :shared_links, :roles => [:web, :app] do
    run "ln -nfs #{shared_path}/config.yml #{release_path}/config/config.yml"
    run "ln -nfs #{shared_path}/mongoid.yml #{release_path}/config/mongoid.yml"
    run "ln -nfs #{shared_path}/config.ru #{release_path}/config.ru"
    run "ln -nfs #{shared_path}/unicorn.rb #{release_path}/unicorn.rb"
    run "ln -nfs #{shared_path}/stats.rb #{release_path}/stats.rb"
    
    # stupid capistrano boilerplate
    run "rm -rf #{File.join release_path, 'tmp'}"
    run "rm #{File.join release_path, 'public', 'system'}"
    run "rm #{File.join release_path, 'log'}"
  end
end