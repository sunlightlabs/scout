set :environment, (ENV['target'] || 'staging')

set :user, 'alarms'
set :application, user
set :sock, "#{user}.sock"

set :deploy_to, "/projects/#{user}/"
set :local_bin, "/projects/#{user}/.gem/ruby/1.8/bin"
set :domain, 'ec2-50-16-84-118.compute-1.amazonaws.com'


set :scm, :git
set :repository, "git@github.com:sunlightlabs/alarms.git"
set :branch, 'master'

set :deploy_via, :remote_cache
set :runner, user
set :admin_runner, runner

role :app, domain
role :web, domain

set :use_sudo, false
after "deploy", "deploy:cleanup"
after "deploy:update_code", "deploy:shared_links"
after "deploy:update_code", "deploy:bundle_install"
after "deploy:update_code", "deploy:create_indexes"


namespace :deploy do
  task :start do
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
    run "cd #{release_path} && #{local_bin}/bundle install --local"
  end
  
  desc "Get shared files into position"
  task :shared_links, :roles => [:web, :app] do
    run "ln -nfs #{shared_path}/config.yml #{release_path}/config/config.yml"
    run "ln -nfs #{shared_path}/config.ru #{release_path}/config.ru"
    run "ln -nfs #{shared_path}/unicorn.rb #{release_path}/unicorn.rb"
    
    # stupid capistrano boilerplate
    run "rm -rf #{File.join release_path, 'tmp'}"
    run "rm #{File.join release_path, 'public', 'system'}"
    run "rm #{File.join release_path, 'log'}"
  end
end