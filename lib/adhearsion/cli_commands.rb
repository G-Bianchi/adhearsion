require 'fileutils'
require 'adhearsion/script_ahn_loader'
require 'thor'

module Adhearsion
  module CLI
    class AhnCommand < Thor
      map %w(-h --h -help --help) => :help
      map %w(-v --v -version --version) => :version
      map %w(-) => :start

      check_unknown_options!

      def self.exit_on_failure?
        true
      end

      desc "create /path/to/directory", "Create a new Adhearsion application under the given path"
      def create(path)
        require 'adhearsion/generators'
        require 'adhearsion/generators/app/app_generator'
        Adhearsion::Generators::AppGenerator.start
      end

      desc "version", "Shows Adhearsion version"
      def version
        say "Adhearsion v#{Adhearsion::VERSION}"
        exit 0
      end

      desc "start </path/to/directory>", "Start the Adhearsion server in the foreground with a console"
      def start(*args)
        start_app args.first, :console
      end

      desc "daemon </path/to/directory>", "Start the Adhearsion server in the background"
      method_option :pidfile, :type => :string, :aliases => %w(--pid-file)
      def daemon(*args)
        start_app args.first, :daemon, options[:pidfile]
      end

      desc "stop </path/to/directory>", "Stop a running Adhearsion server"
      method_option :pidfile, :type => :string, :aliases => %w(--pid-file)
      def stop(*args)
        path = args.first
        raise CLIException, "Directory is not an Adhearsion application!" unless
          ScriptAhnLoader.in_ahn_application?(args.first)

         STDERR.puts options.inspect

        if options[:pidfile]
          pid_file = File.expand_path File.exists?(File.expand_path(options[:pidfile])) ?
          options[:pidfile] :
          File.join(path, options[:pidfile])
        else
          pid_file = path + '/adhearsion.pid'
        end

        STDERR.puts pid_file.inspect

        STDERR.puts File.exists?(pid_file)

        begin
          pid = File.read(pid_file).to_i
        rescue
          STDERR.puts "Could not read pid file #{pid_file}"
          #logger.warn "Could not read pid file #{pid_file}"
          #raise CLIException, "Could not read pid file #{pid_file}"
        end

        unless pid.nil?
          say "Stopping Adhearsion server at #{path}"
          waiting_timeout = Time.now + 15
          ::Process.kill("TERM", pid)
          sleep 0.25 until !process_exists?(pid) || Time.now > waiting_timeout
          ::Process.kill("KILL", pid)
        end
      end

      desc "restart </path/to/directory>", "Restart the Adhearsion server"
      method_option :pidfile, :type => :string, :aliases => %w(--pid-file)
      def restart(path)
        invoke :stop
        invoke :daemon
      end

      protected

      def start_app(path, mode, pid_file = nil)
        execute_from_app_dir!(path, ARGV) unless in_app?
        say "Starting Adhearsion server at #{path}"
        Adhearsion::Initializer.start :mode => mode, :pid_file => pid_file
      end

      def execute_from_app_dir!(app_path, *args)
        Dir.chdir app_path do
          ScriptAhnLoader.exec_script_ahn! *args
        end
      end

      def in_app?
        ScriptAhnLoader.in_ahn_application? or ScriptAhnLoader.in_ahn_application_subdirectory?
      end

      def process_exists?(pid = nil)
        # FIXME: Raise some error here
        return false if pid.nil?
        `ps -p #{pid} | sed -e '1d'`.strip.empty?
      end

      def method_missing(action, *args)
        help
        raise UnknownCommand, [action, *args] * " "
      end
    end # AhnCommand

    class UnknownCommand < Thor::Error
      def initialize(cmd)
        super "Unknown command: #{cmd}"
      end
    end

    class PathInvalid < Thor::Error
      def initialize(path)
        super "Directory #{path} does not belong to an Adhearsion project!"
      end
    end
  end
end
