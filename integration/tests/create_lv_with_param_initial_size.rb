require 'master_manipulator'
require 'lvm_helper'
require 'securerandom'

test_name "FM-4579 - C96576 - create logical volume with parameter 'initial_size'"

#initilize
pv = ['/dev/sdb', '/dev/sdc']
vg = ("VG_" + SecureRandom.hex(2))
lv = ("LV_" + SecureRandom.hex(3))

# Teardown
teardown do
  confine_block(:except, :roles => %w{master dashboard database}) do
    on(agent, "umount /dev/#{vg}/#{lv}", :acceptable_exit_codes => [0,1])
    on(agent, "lvremove /dev/#{vg}/#{lv} --force")
    on(agent, "vgremove #{vg}")
    pv.each do |physical_volume|
      on(agent, "pvremove #{physical_volume}")
    end
  end
end

pp = <<-MANIFEST
volume_group {'#{vg}':
  ensure            => present,
  physical_volumes  => #{pv}
}
->
logical_volume{'#{lv}':
  ensure        => present,
  volume_group  => '#{vg}',
  initial_size  => '2G',
}
MANIFEST

step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, :manifest => pp)
inject_site_pp(master, get_site_pp_path(master), site_pp)

step 'Run Puppet Agent to create logical volumes'
confine_block(:except, :roles => %w{master dashboard database}) do
  agents.each do |agent|
    on(agent, puppet('agent -t --graph  --environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    end

    step "Verify the logical volume  is created: #{lv}"
    verify_if_created?(agent, 'logical_volume', lv)
  end
end
