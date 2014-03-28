import time
from fabric.api import run, execute, env

env.use_ssh_config = True

branch = "master"
repo = "git://github.com/sunlightlabs/scout.git"

# keep 10 releases at a time on disk
keep = 10

# default to staging, override with "fab [command] --set target=production"
target = env.get('target', 'staging')

if target == "staging":
  env.hosts = ["alarms@dupont"]
  username = "alarms"
elif target == "production":
  env.hosts = ["scout@scout"]
  username = "scout"


home = "/projects/%s" % username
shared_path = "%s/shared" % home
versions_path = "%s/versions" % home
version_path = "%s/%s" % (versions_path, time.strftime("%Y%m%d%H%M%S"))
current_path = "%s/current" % home


## can be run only as part of deploy

def cleanup():
  versions = run("ls -x %s" % versions_path).split()
  destroy = versions[:-keep]

  for version in destroy:
    command = "rm -rf %s/%s" % (versions_path, version)
    run(command)


def checkout():
  run('git clone -q -b %s %s %s' % (branch, repo, version_path))

def links():
  run("ln -s %s/system %s/public/system" % (shared_path, version_path))
  run("ln -s %s/sitemap %s/public/sitemap" % (shared_path, version_path))
  run("ln -s %s/config.yml %s/config/config.yml" % (shared_path, version_path))
  run("ln -s %s/services.yml %s/config/services.yml" % (shared_path, version_path))
  run("ln -s %s/config.ru %s/config.ru" % (shared_path, version_path))
  run("ln -s %s/unicorn.rb %s/unicorn.rb" % (shared_path, version_path))

  # default to a robots.txt.else rather than a robots.txt,
  # so that if this fails for some reason, we end up with no robots.txt
  # rather than a don't-index-anything robots.txt.
  if target == "production":
    robots = "production"
  else:
    robots = "else"

  run("cp %s/public/robots.txt.%s %s/public/robots.txt" % (version_path, robots, version_path))

def dependencies():
  run("cd %s && bundle install --local" % version_path)

def create_indexes():
  run("cd %s && rake create_indexes" % version_path)

def sync_assets():
  run("cd %s && rake assets:sync" % version_path)

def make_current():
  run('rm -f %s && ln -s %s %s' % (current_path, version_path, current_path))


## can be run on their own

def set_crontab():
  run("cd %s && rake crontab:set environment=%s current_path=%s" % (current_path, target, current_path))

def disable_crontab():
  run("cd %s && rake crontab:disable" % current_path)

def start():
  run("cd %s && bundle exec unicorn -D -l %s/%s.sock -c unicorn.rb" % (current_path, shared_path, username))

def stop():
  run("kill `cat %s/unicorn.pid`" % shared_path)

def restart():
  run("kill -USR2 `cat %s/unicorn.pid`" % shared_path)

def clear_cache():
  run("cd %s && rake clear_cache" % current_path)


def deploy():
  execute(checkout)
  execute(links)
  execute(dependencies)
  execute(create_indexes)
  execute(sync_assets)
  execute(make_current)
  execute(set_crontab)
  execute(restart)
  execute(cleanup)

# only difference is it uses start instead of restart
def deploy_cold():
  execute(checkout)
  execute(links)
  execute(dependencies)
  execute(create_indexes)
  execute(sync_assets)
  execute(make_current)
  execute(set_crontab)
  execute(start)
