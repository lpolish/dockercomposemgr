FROM ruby:3.2-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    tzdata \
    nodejs \
    yarn

# Set working directory
WORKDIR /app

# Install Rails
RUN gem install rails

# Copy Gemfile and install dependencies
COPY Gemfile* ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Add a script to be executed every time the container starts
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Start the main process
CMD ["rails", "server", "-b", "0.0.0.0"] 