require 'open3'

require_relative 'gitlab_net'

class GitlabShell
  attr_accessor :key_id, :repo_name, :git_cmd, :repos_path, :repo_name, :args

  def initialize
    @key_id = /key-[0-9]+/.match(ARGV.join).to_s
    @origin_cmd = ENV['SSH_ORIGINAL_COMMAND']
    @config = GitlabConfig.new
    @repos_path = @config.repos_path
    @user_tried = false
  end

  def exec
    if @origin_cmd
      parse_cmd

      if git_cmds.include?(@git_cmd)
        ENV['GL_ID'] = @key_id

        if validate_access
          process_cmd
        else
          message = "gitlab-shell: Access denied for git command <#{@origin_cmd}> by #{log_username}."
          $logger.warn message
          $stderr.puts "Access denied."
        end
      else
        message = "gitlab-shell: Attempt to execute disallowed command <#{@origin_cmd}> by #{log_username}."
        $logger.warn message
        puts 'Not allowed command'
      end
    else
      puts "Welcome to GitLab, #{username}!"
    end
  end

  protected

  def parse_cmd
    @args = @origin_cmd.split(' ')
    @git_cmd = args.shift
    @repo_name = args.shift
  end

  def git_cmds
    %w(git-upload-pack git-receive-pack git-upload-archive)
  end

  def process_cmd
    repo_full_path = File.join(repos_path, repo_name)
    cmd = "#{@git_cmd} #{repo_full_path}"
    $logger.info "gitlab-shell: executing git command <#{cmd}> for #{log_username} #{@args}."
    exec_cmd(cmd)
  end

  def validate_access
    api.allowed?(@git_cmd, @repo_name, @key_id, '_any')
  end

  def exec_cmd args
    Kernel::exec args
  end

  def api
    GitlabNet.new
  end

  def user
    # Can't use "@user ||=" because that will keep hitting the API when @user is really nil!
    if @user_tried
      @user
    else
      @user_tried = true
      @user = api.discover(@key_id)
    end
  end

  def username
    user && user['name'] || 'Anonymous'
  end

  # User identifier to be used in log messages.
  def log_username
    @config.audit_usernames ? username : "user with key #{@key_id}"
  end
end
