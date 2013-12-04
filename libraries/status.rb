module DatomicLibrary
  module Mixin
    module Status
      include DatomicLibrary::Mixin::Attributes
      include Chef::Mixin::ShellOut

      def already_installed?
        ::File.symlink?(datomic_run_dir)
      end

      def is_running?
        datomic_status.exitstatus == 0
      end

      def running_version
        if(is_running?)
          output = datomic_status.stdout
          match = output.match(/datomic-transactor-(pro|free)-(\d+\.\d+.\d+)/)
          if match
            match[2]
          end
        end
      end

      def version_changing?
        node[:datomic][:version] != running_version
      end

      private

      def datomic_status
        @status ||= shell_out('ps auxw | grep -v grep | grep datomic-transactor').run_command
      end
    end
  end
end
