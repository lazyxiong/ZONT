# -- this script needs to be run after ZONT was started with "drb" option, eg:
#    ruby drb_client.rb tests/login_logout_test.rb
require 'drb'
require "timeout"

@class       = ARGV[0]
@tests       = nil
@test        = nil
@exit_status = nil
STDOUT.sync  = true

raise "-- ERROR: must supply valid test as an argument !" unless @class
raise "-- ERROR: test not found (#{@class}) !" unless File.file?(@class)

# -- establish connection to drb server and find our test
DRb.start_service()
@obj = DRbObject.new(nil, 'druby://localhost:9000')
@config = @obj.config
@tests = @obj.tests
@tests.extend DRbUndumped
@tests.each { |t| @test = t if @class.include?(t.execute_class) }
exit 0 unless @test # -- if our test is not supposed to be running, we simply exit here

def run_test(cmd)
   tStart = Time.now
   @out = "-- #{tStart.strftime('[%H:%M:%S]')} running: [#{cmd}] "
   begin
      status = Timeout::timeout(@test.timeout.to_i) {
         output = `#{cmd} 2>&1`
	 @test.output = output
         @exit_status = case @test.output
            when /#{@config['test_exit_message_passed']}/ then @config['test_exit_message_passed']
            when /#{@config['test_exit_message_failed']}/ then @config['test_exit_message_failed']
            else @config['test_exit_message_failed']
          end
      }
   rescue Timeout::Error => e
      @test.output << "\n\n[ TERMINATED WITH TIMEOUT (#{@test.timeout.to_s}) ]"
      @exit_status = @config['test_exit_message_failed']
   rescue => e
      @test.output << "\n\n[ ERROR ]\n\n"
      @test.output << e.inspect
      @exit_status = @config['test_exit_message_failed']
   ensure
      @obj.p(@out.to_s + @exit_status.to_s)
      @obj.p(@output) if @config['output_on']
   end
   tFinish = Time.now
   @test.execution_time = tFinish - tStart
end

# -- run the test
cmd = @config['interpreter'] + " " + @test.execute_class
cmd = cmd + " " + @test.execute_args unless @test.execute_args == ""
run_test(cmd)

# -- do we run test more than once if it failed first time ?
if (@exit_status == @config['test_exit_message_failed']) and (@config['test_retry'] > 0)
   @obj.inc_tests_retried_counter
   retried_counter = 0
   while(retried_counter < @config['test_retry'])
      retried_counter += 1
      run_test(cmd)
      retried_counter = @config['test_retry'] if @exit_status == @config['test_exit_message_passed']
   end
end

# -- set @test's exit_status and write the @test's log
@test.exit_status = @exit_status
@test.write_log

# -- check if all tests are done and if so - stop drb
done = true
@tests.each { |t| done = false if t.exit_status == "" }
if done
   @obj.p("\n\n-- class {#{@class}} stopping drb\n\n")
   begin
      @obj.stop_drb
      DRb.stop_service()
   rescue => e
      exit(true)
   end
end
