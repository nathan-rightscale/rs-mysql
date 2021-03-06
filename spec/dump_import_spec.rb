require_relative 'spec_helper'

describe 'rs-mysql::dump_import' do

  context 'rs-mysql/import/private_key is NOT set' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['cloud']['private_ips'] = ['10.0.2.15']
        node.set['memory']['total'] = '1011228kB'
        node.set['rs-mysql']['backup']['lineage'] = 'testing'
        node.set['rs-mysql']['server_repl_password'] = 'replpass'
        node.set['rs-mysql']['server_root_password'] = 'rootpass'
        node.set['rs-mysql']['import']['repository'] = 'https://github.com/rightscale/examples.git'
        node.set['rs-mysql']['import']['revision'] = 'master'
        node.set['rs-mysql']['import']['dump_file'] = 'app_test.sql.bz2'

      end.converge(described_recipe)
    end

    it 'installs git' do
      expect(chef_run).to include_recipe('git')
    end

    it 'will not create key_file' do
      expect(chef_run).to_not create_file('/tmp/git_key')
    end

    it 'will not create git_ssh wrapper' do
      expect(chef_run).to_not create_file('/tmp/git_ssh.sh')
    end

    it 'downloads git repository without ssh_wrapper' do
      expect(chef_run).to sync_git('/tmp/git_download').with(
        repository: 'https://github.com/rightscale/examples.git',
        revision: 'master',
        ssh_wrapper: nil
      )
    end

    it 'deletes key_file and git_ssh wrapper file' do
      expect(chef_run).to delete_file('/tmp/git_key')
      expect(chef_run).to delete_file('/tmp/git_ssh.sh')
    end

    it 'installs supported compression packages' do
      expect(chef_run).to install_package('gzip')
      expect(chef_run).to install_package('bzip2')
      expect(chef_run).to install_package('xz-utils')
    end

    it 'restores from mysql dump file' do
      expect(chef_run).to query_mysql_database('app_test.sql.bz2-master').with(
        connection: { host: 'localhost', username: 'root', password: 'rootpass' }
      )
    end

    it 'assures that /var/lib/rightscale directory exists' do
      expect(chef_run).to create_directory('/var/lib/rightscale').with(
        mode: 0755,
        recursive: true
      )
    end

    it 'deletes destination directory' do
      expect(chef_run).to delete_directory('/tmp/git_download').with(recursive: true)
    end
  end

  context 'rs-mysql/import/private_key is set' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['rs-mysql']['server_root_password'] = 'rootpass'
        node.set['rs-mysql']['import']['repository'] = 'git@github.com:rightscale/examples.git'
        node.set['rs-mysql']['import']['revision'] = 'unified_php'
        node.set['rs-mysql']['import']['dump_file'] = 'app_test.sql.bz2'
        node.set['rs-mysql']['import']['private_key'] = 'private_key_data'
      end.converge(described_recipe)
    end

    it 'installs git' do
      expect(chef_run).to include_recipe('git')
    end

    it 'creates key_file' do
      expect(chef_run).to create_file('/tmp/git_key').with(
        owner: 'root',
        group: 'root',
        mode: '0700'
      ).with_content('private_key_data')
    end

    it 'creates git_ssh wrapper' do
      expect(chef_run).to create_file('/tmp/git_ssh.sh').with(
        owner: 'root',
        group: 'root',
        mode: '0700'
      ).with_content('exec ssh -o StrictHostKeyChecking=no -i /tmp/git_key "$@"')
    end

    it 'downloads git repository with ssh_wrapper' do
      expect(chef_run).to sync_git('/tmp/git_download').with(
        repository: 'git@github.com:rightscale/examples.git',
        revision: 'unified_php',
        ssh_wrapper: '/tmp/git_ssh.sh'
      )
    end

    it 'deletes key_file and git_ssh wrapper file' do
      expect(chef_run).to delete_file('/tmp/git_key')
      expect(chef_run).to delete_file('/tmp/git_ssh.sh')
    end

    it 'installs bzip2' do
      expect(chef_run).to install_package('bzip2')
    end

    it 'restores from mysql dump file' do
      expect(chef_run).to query_mysql_database('app_test.sql.bz2-unified_php').with(
        connection: { host: 'localhost', username: 'root', password: 'rootpass' }
      )
    end

    it 'assures that /var/lib/rightscale directory exists' do
      expect(chef_run).to create_directory('/var/lib/rightscale').with(
        mode: 0755,
        recursive: true
      )
    end

    it 'deletes destination directory' do
      expect(chef_run).to delete_directory('/tmp/git_download').with(recursive: true)
    end
  end
end
