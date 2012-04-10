require 'drb'
require "timeout"

@class = "tests/account/login_logout_test.rb"
@test  = nil

# -- establish connection to drb server and find our test
DRb.start_service()
@obj = DRbObject.new(nil, 'druby://localhost:9000')
@obj.tests.each { |t| @test = t if @class.include?(t.execute_class) }
@config = @obj.config

def run_test(cmd)
   tStart = Time.now
   begin
      status = Timeout::timeout(@test.timeout.to_i) {
         @obj.p("-- #{tStart.strftime('[%H:%M:%S]')} running: [#{cmd}] ")
         @test.output = `#{cmd} 2>&1`
         @test.exit_status = case @test.output
            when /#{@config['test_exit_message_passed']}/ then @config['test_exit_message_passed']
            when /#{@config['test_exit_message_failed']}/ then @config['test_exit_message_failed']
            else @config['test_exit_message_failed']
          end
      }
   rescue Timeout::Error => e
      @test.output << "\n\n[ TERMINATED WITH TIMEOUT (#{@test.timeout.to_s}) ]"
      @test.exit_status = @config['test_exit_message_failed']
   end
   tFinish = Time.now
   @test.execution_time = tFinish - tStart
end

# -- run the test
@obj.executed_tests += 1
cmd = @config['interpreter'] + " " + @test.execute_class
cmd = cmd + " " + @test.execute_args unless @test.execute_args == ""
run_test(cmd)

# -- do we run test more than once if it failed first time ?
if (@test.exit_status == @config['test_exit_message_failed']) and (@config['test_retry'] > 0)
   @obj.tests_retried_counter += 1
   retried_counter = 0
   while(retried_counter < @config['test_retry'])
      retried_counter += 1
      run_test(cmd)
      retried_counter = @config['test_retry'] if @test.exit_status == @config['test_exit_message_passed']
   end
end

# -- check if all tests are done and if so - stop drb
done = true
@obj.tests.each { |t| done = false if t.exit_status == "" }
if done
   @obj.stop_drb
   DRb.stop_service()
end
