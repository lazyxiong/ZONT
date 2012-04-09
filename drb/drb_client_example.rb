require 'drb'

cmd = "ruby tests/account/login_logout_test.rb"
#`#{cmd} 2>&1`

DRb.start_service()
obj = DRbObject.new(nil, 'druby://localhost:9000')
obj.tests.each { |t|
   if cmd.include?(t.execute_class)
      # -- 1: assign execution status and output to #{t}
      t.exit_status = "OK"
   end
}

# -- 2: check if all tests are done and if so - stop drb
done = true
obj.tests.each { |t| done = false if t.exit_status == "" }
obj.stop_drb if done
