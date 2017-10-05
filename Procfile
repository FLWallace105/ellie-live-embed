web: bundle exec rackup config.ru -p $PORT
worker: COUNT=8 QUEUE=* rake resque:work QUEUE='*'
