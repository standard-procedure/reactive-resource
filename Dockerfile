FROM ruby:3.1.3
# Set up the image
RUN curl -fsSL https://deb.nodesource.com/setup_19.x | bash -
RUN apt-get -y update -y && apt-get -y upgrade && apt-get install -y build-essential curl imagemagick memcached nodejs

WORKDIR /usr/src/app
COPY ./lib /usr/src/app/lib/
COPY Gemfile Gemfile.lock standard_procedure.gemspec /usr/src/app/
RUN bundle update --bundler
RUN bundle check || bundle install
COPY . /usr/src/app

