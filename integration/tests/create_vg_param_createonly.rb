require 'master_manipulator'
require 'lvm_helper'
require 'securerandom'

test_name "FM-4579 - C96596 - create volume group with parameter 'createonly'"

#initilize
pv = '/dev/sdb'
vg = ("VG_" + SecureRandom.hex(3))

# Teardown
teardown do
  confine_block(:except, :roles => %w{master dashboard database}) do
    on(agent, "vgremove #{vg}")
    on(agent, "pvremove #{pv}")
  end
end

pp = <<-MANIFEST
physical_volume {'#{pv}':
  ensure => present,
}
->
volume_group {"#{vg}":
  ensure            => present,
  createonly        => true,
  physical_volumes  => '#{pv}',
}

MANIFEST

step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, :manifest => pp)
inject_site_pp(master, get_site_pp_path(master), site_pp)

step 'Run Puppet Agent to create volume group'
confine_block(:except, :roles => %w{master dashboard database}) do
  agents.each do |agent|
    on(agent, puppet('agent -t --graph  --environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    end

    step "Verify the volume group is created: #{vg}"
    verify_if_created?(agent, 'volume_group', vg)
  end
end
