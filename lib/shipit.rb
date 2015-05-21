require 'active_support/all'
require 'active_model_serializers'
require 'state_machines-activerecord'
require 'validate_url'
require 'responders'
require 'explicit-parameters'

require 'sass-rails'
require 'coffee-rails'
require 'jquery-rails'
require 'rails-timeago'
require 'ansi_stream'

require 'omniauth-github'

require 'pubsubstub'
require 'safe_yaml/load'
require 'securecompare'

require 'redis-objects'

require 'octokit'
require 'faraday-http-cache'

require 'shipit/null_serializer'
require 'shipit/csv_serializer'
require 'shipit/octokit_iterator'
require 'shipit/first_parent_commits_iterator'
require 'shipit/simple_message_verifier'

require 'command'
require 'commands'
require 'stack_commands'
require 'task_commands'
require 'deploy_commands'
require 'rollback_commands'

require 'shipit/engine'

SafeYAML::OPTIONS[:default_mode] = :safe
SafeYAML::OPTIONS[:deserialize_symbols] = false

module Shipit
  extend self

  def app_name
    @app_name ||= secrets.app_name || Rails.application.class.name.split(':').first
  end

  def redis_url
    @redis_url ||= URI(secrets.redis_url.presence || fail("Missing `redis_url` setting in secrets.yml"))
  end

  def redis
    @redis ||= Redis.new(url: redis_url.to_s, logger: Rails.logger)
  end

  def github_api
    @github_api ||= begin
      credentials = secrets.github_credentials || {}
      client = Octokit::Client.new(credentials.symbolize_keys)
      client.middleware.use(
        Faraday::HttpCache,
        shared_cache: false,
        store: Rails.cache,
        logger: Rails.logger,
        serializer: NullSerializer,
      )
      client
    end
  end

  def api_clients_secret
    secrets.api_clients_secret || ''
  end

  def host
    secrets.host.presence || fail("Missing `host` setting in secrets.yml")
  end

  def github_required?
    github.present? && !github['optional']
  end

  def github_team
    @github_team ||= github['team'] && Team.find_or_create_by_handle(github['team'])
  end

  def github_key
    github['key']
  end

  def github_secret
    github['secret']
  end

  def github
    secrets.github || {}
  end

  def extra_env
    secrets.env || {}
  end

  def revision
    @revision ||= begin
      if revision_file.exist?
        revision_file.read
      else
        `git rev-parse HEAD`
      end.strip
    end
  end

  protected

  def revision_file
    Rails.root.join('REVISION')
  end

  def secrets
    Rails.application.secrets
  end
end