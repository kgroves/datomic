use_inline_resources

include DatomicLibrary::Mixin::Attributes
include DatomicLibrary::Mixin::Status

action :install do

  remote_file local_file_path do
    source datomic_download_url
    owner username
    group username
    checksum node[:datomic][:checksum]
  end

  execute "unzip #{local_file_path} -d #{home_dir}" do
    cwd download_dir
    not_if { ::File.exists?(temporary_zip_dir) }
  end

  execute "chown -R #{username}:#{username} #{temporary_zip_dir}"

  link datomic_run_dir do
    to temporary_zip_dir
    owner username
    group username
  end

  protocol = node[:datomic][:protocol]

  if(protocol == 'sql')
    ojdbc_jar_url = node[:datomic][:ojdbc_jar_url]

    raise 'You must set node[:datomic][:ojdbc_jar_url]' if ojdbc_jar_url.nil?
    raise 'The sql protocol requires a datomic license, specify with node[:datomic][:datomic_license_key]' if node[:datomic][:datomic_license_key].nil?

    ojdbc_file = "#{datomic_run_dir}/lib/ojdbc.jar"

    remote_file ojdbc_file do
      source ojdbc_jar_url
      owner username
      group username
      checksum node[:datomic][:ojdbc_jar_checksum]
    end
  end

  template "#{datomic_run_dir}/transactor.properties" do
    source 'transactor.properties.erb'
    owner username
    group username
    cookbook 'datomic'
    mode 00755
    variables(
      :hostname => node[:hostname],
      :sql_user => node[:datomic][:sql_user],
      :sql_password => node[:datomic][:sql_password],
      :sql_url => node[:datomic][:sql_url],
      :license_key => node[:datomic][:datomic_license_key],
      :protocol => protocol
    )
  end

  run_dir = datomic_run_dir

  should_destroy = is_running? && version_changing?

  java_service 'datomic' do
    action [:stop, :disable]
    only_if { should_destroy }
  end

  java_service 'datomic' do
    action [:create, :enable, :load, :start]
    user username
    working_dir run_dir
    standard_options({:server => nil})
    main_class 'clojure.main'
    classpath Proc.new { Mixlib::ShellOut.new('bin/classpath', :cwd => run_dir).run_command.stdout.strip }
    args(['--main', 'datomic.launcher', 'transactor.properties'])
    pill_file_dir run_dir
    log_file "#{run_dir}/datomic.log"
    only_if { version_changing? }
  end

  java_service 'datomic' do
    action :restart
    only_if { is_running? && !version_changing? }
  end

end
