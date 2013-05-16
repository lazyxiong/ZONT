#    Copyright (C) 2010 Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# -- usage: rake help

require 'rubygems'
require 'net/pop'
require 'net/smtp'
require 'net/http'
require 'uri'
# -- get rid of annoying warnings about defined variables
require 'net/pop'
Net.instance_eval {remove_const :POP} if defined?(Net::POP)
Net.instance_eval {remove_const :POPSession} if defined?(Net::POPSession)
Net.instance_eval {remove_const :POP3Session} if defined?(Net::POP3Session)
Net.instance_eval {remove_const :APOPSession} if defined?(Net::APOPSession)
Net::POP3.instance_eval {remove_const :Revision} if defined?(Net::POP3::Revision)
require 'net/smtp'
Net.instance_eval {remove_const :SMTPSession} if defined?(Net::SMTPSession)
require 'tlsmail'
require "timeout"
require "fileutils"
require "yaml"
require "drb"
require "thread"
require 'google_spreadsheet'

# -- global vars
task :default => [:run]
STDOUT.sync = true
@suite_root            = File.expand_path "#{File.dirname(__FILE__)}"
@rake_env_file         = "#{@suite_root}/rake.env.yaml"
@rake_env_user_file    = "#{@suite_root}/user.rake.env.yaml"
@exclude_list_file     = "#{@suite_root}/exclude_list.txt"
@tests                 = []
@reports_dir           = ENV['HOME'] + "/rake_reports" # -- default
@reports_dir           = ENV['REPORTS_DIR'] if ENV['REPORTS_DIR'] != nil
ENV["REPORTS_DIR"]     = @reports_dir
#
# -- the following vars control the behavior of running tests: default values
@config = {
   'output_on'                 => false,
   'test_retry'                => 0,
   'test_exit_message_passed'  => "PASSED",
   'test_exit_message_failed'  => "FAILED",
   'test_exit_message_skipped' => "SKIPPED",
   'xml_report_class_name'     => "qa.tests",
   'xml_report_file_name'      => "TESTS-TestSuites.xml",
   'interpreter'               => "ruby",
   'test_extension'            => ".rb",
   'excludes'                  => ".svn",
   'test_dir'                  => "tests",
   'test_timeout'              => 1200, # -- miliseconds
   # -- related to parallel execution (DRb)
   'between_batch_wait_time'   => 200,  # -- wait 200 seconds (a little over 3 min) for a batch of tests to finish execution, before starting next batch
   'batch_size'                => 5,    # -- default batch size (5 tests to run in parallel)
   # -- exclude_list
   'exclude_list'              => [],
   # -- statistics report ?
   'publish_statistics'        => false,
   'statistics_test_list'      => "",
   'gs_credentials'            => { 'key' => "", 'user' => "", 'password' => "" },
   # -- mail related vars
   'pop_host'                  => "pop.gmail.com",
   'pop_port'                  => 995,
   'smtp_host'                 => "smtp.gmail.com",
   'smtp_port'                 => 587,
   'mail_domain'               => "gmail.com",
   'user_name'                 => "",
   'user_passwd'               => "",
   'reply_email'               => "",
   'use_jenkins'               => false,
   'jenkins_job_url'           => "",
   'jenkins_job_parameter'     => "",
   'two_step_authentication'   => false
}

#    *************************** BEGIN SETUP ***************************

# -- write out test data hash into a YAML file to hold basic ZONT environment
def write(filename, hash)
   File.open(filename, "w") { |f| f.write(hash.to_yaml) }
end

# -- if 'rake.env.yaml' exists, load values from there into @config hash; otherwise write defaults to newly created 'rake.env.yaml' file.
if File.exist?(@rake_env_file)
   @config.merge!(YAML::load(File.read(@rake_env_file)))
else
   puts "\n\n-- INFO: {#{@rake_env_file}}  doesn't exist, it will be created with default values.\n\n"
   write(@rake_env_file, @config)
end
# -- loading user-defined properties from yaml: if 'user.rake.env.yaml' file exists, we'll use it to overwrite @config hash
if File.exist?(@rake_env_user_file)
   YAML::load(File.read(@rake_env_user_file)).each_pair { |key, value|
      @config[key] = value if @config[key] != nil
   }
end
# -- merge any other variables that we don't want to be stored in the 'rake.env' file into @config hash
@config.merge!({'reports_dir' => @reports_dir})

# -- do we have exclude_list ?
@config['exclude_list'] = File.read(@exclude_list_file) if File.exists?(@exclude_list_file)

#    *************************** END SETUP ***************************

# -- usage
desc "-- usage"
task :help do
    puts "\n-- usage: \n\n"
    puts "   rake help                                     : print this message"
    puts "   rake                                          : this will by default run :run task, which runs all tests"
    puts "   rake run KEYWORDS=<keyword1,keyword2>         : this will run tests based on keyword"
    puts "   rake drb KEYWORDS=<keyword1,keyword2>         : this will run framework in DRb mode and execute tests in parallel, where each test is invoked by drb client"
    puts "   rake print_human                              : this will print descriptions of your tests"
    puts "   rake print_human KEYWORDS=<keyword1,keyword2> : same as above, but only for tests corresponding to KEYWORDS"
    puts "   rake REPORTS_DIR=</path/to/reports>           : this will set default reports dir and run all tests"
    puts "   rake mail_gateway                             : this will activate email remote control which will listen for remote commands"
    puts "   rake mail_gateway_help                        : prints basic help for using email remote control\n\n"
    puts "   Eg:\n\n   rake KEYWORDS=<keyword1, keyword2> REPORTS_DIR=/somewhere/path\n\n\n"
    puts "   Sample comments in your tests (eg: tests/some_test.rb):\n\n"
    puts "   # @author Alexandre Berman"
    puts "   # @executeArgs"
    puts "   # @keywords acceptance"
    puts "   # @description some interesting test\n\n"
    puts "   Note 1:\n\n   Your test must end with 'test.rb' - otherwise Rake won't be able to find it, eg:\n"
    puts "   tests/some_new_test.rb\n\n"
    puts "   Note 2:\n\n   Your test must define at least one keyword.\n\n\n"
    puts "   'rake.yaml' file will be created (if it doesn't already exist) with default values controlling behavior of Rake.\n\n\n"
end

# -- mail gateway usage
def mail_help
   xxx  = "-- Following messages are supported: \n\n"
   xxx += "  '==help==' system will reply with this message\n"
   xxx += "  '==list==' system will reply with list of available programs\n"
   xxx += "  '==play <KEYWORD>==' system will run a program specified by 'KEYWORD'\n\n"
   return xxx
end

# -- mail gateway usage
desc "-- mail gateway usage"
task :mail_gateway_help do
   puts mail_help
end

# -- prepare reports_dir
def prepare_reports_dir
   FileUtils.rm_r(@config['reports_dir']) if File.directory?(@config['reports_dir'])
   FileUtils.mkdir_p(@config['reports_dir'])
end

# -- filtering by keywords
def filter_by_keywords
   # -- do we have keywords set ?
   if (ENV['KEYWORDS'] != nil and ENV['KEYWORDS'].length > 0)
      tmp_tests = []
      # -- loop through all keywords
      ENV['KEYWORDS'].gsub(/,/, ' ').split.each { |keyword|
         # -- loop through all tests
         @tests.each { |t|
            # -- loop through all keywords for a given test
            t.keywords.each { |k|
               if k == keyword
                  tmp_tests << t
               end
            }
         }
      }

      # -- in case only a negative keyword was given, let's fill up tmp_tests array here (ie: if it is empty now):
      tmp_tests = @tests.uniq if tmp_tests.length < 1 and /!/.match(ENV['KEYWORDS'])

      # -- check for a negative keyword
      if /!/.match(ENV['KEYWORDS'])
         ENV['KEYWORDS'].gsub(/,/, ' ').split.each { |keyword|
            if /!/.match(keyword)
               keyword.gsub!(/!/, '')
               # -- loop through all tests
               @tests.each { |t|
                  # -- loop through all keywords for a given test
                  t.keywords.each { |k|
                     # -- if keyword matches with negative keyword, remove this test from the array
                     if k == keyword
                        tmp_tests.delete(t)
                     end
                  }
               }
            end
         }
      end
      # -- replace original @tests with tmp_tests array
      @tests = tmp_tests.uniq
   end
end

# -- load test: populate a hash with right entries and create a Test object for it
def load_test(tc)
   data = Hash.new
   File.open(tc, "r") do |infile|
      while (line = infile.gets)
         #test                  = /^.*\/(.*\.rb)/.match(tc)[1]
         test                  = /^.*\/([A-Za-z0-9_-]*[T|t]est.*)/.match(tc)[1]
         data['execute_class'] = /^([A-Za-z0-9_-]*[T|t]est.*)/.match(tc)[1]
         data['path']          = /(.*)\/#{test}/.match(tc)[1]
         data['execute_args']  = /^#[\s]*@executeArgs[\s]*(.*)/.match(line)[1] if /^#[\s]*@executeArgs/.match(line)
         data['author']        = /^#[\s]*@author[\s]*(.*)/.match(line)[1] if /^#[\s]*@author/.match(line)
         data['keywords']      = /^#[\s]*@keywords[\s]*(.*)/.match(line)[1].gsub(/,/,'').split if /^#[\s]*@keywords/.match(line)
         data['description']   = /^#[\s]*@description[\s]*(.*)/.match(line)[1] if /^#[\s]*@description/.match(line)
      end
   end
   @tests << Test.new(data, @config) if data['keywords'] != nil and data['keywords'] != ""
end

# -- find tests and load them one by one, applying keyword-filter at the end
desc "-- find all tests..."
task :find_all do
   FileList["#{@config['test_dir']}/**/*[T|t]est#{@config['test_extension']}"].exclude(@config['excludes']).each { |tc_name|
      load_test(tc_name)
   }
   filter_by_keywords
end

# -- BEGIN EMAIL GATEWAY RELATED CODE

# -- do_reply
def do_reply(subject, msg)
   full_msg=<<END_OF_MESSAGE
From: #{@config['user_name']}
To: #{@config['reply_email']}
Subject: #{subject}
Date: #{Time.now}

#{msg}
END_OF_MESSAGE
   Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
   Net::SMTP.start(@config['smtp_host'], @config['smtp_port'], @config['mail_domain'], @config['user_name'], @config['user_passwd'], :login) { |smtp|
      smtp.send_message(full_msg, @config['user_name'], @config['reply_email'])
   }
end

# -- play received request
def play_request(keyword)
   # -- we either execute program marked by received keyword directly, or trigger Jenkins build
   if @config['use_jenkins']
      url = @config['jenkins_job_url'] + @config['jenkins_job_parameter'] + "=" + keyword
      Net::HTTP.get(URI.parse("#{url}"))
      xxx = "-- Jenkins job was invoked with supplied parameter: " + keyword + "\n\n-- url: " + url
      do_reply("-- Jenkins job invoked", xxx)
   else
      xxx  = "-- executing: rake KEYWORDS='" + keyword + "'\n\n"
      xxx += `rake KEYWORDS='#{keyword}'`
      do_reply("-- status of playback delivered", xxx)
   end
end

# -- two_step_authenticate: send random number to reply_to email
def authentication_send_code(keyword)
   # -- first: save received keyword with the code for later matching
   code = rand(50000).to_s
   file = @suite_root + "/" + code + ".au"
   File.open(file, "w") { |f| f.write(keyword) }
   # -- then: send random code for authentication
   do_reply("-- authenticate yourself by replying to this email", "==authentication: #{code}==")
end

# -- two_step_authenticate: process received code and match with what was sent
def authentication_process_code(code)
   # -- match received code against a file with same name: its content should be the keyword to play
   #    if file doesn't exist, then we just ignore the whole thing - that means authentication failed !
   file    = @suite_root + "/" + code + ".au"
   if File.exist?(file)
      keyword = File.open(file, 'r') { |f| f.read }
      File.delete(file)
      play_request(keyword)
   end
end

# -- pop mail
def pop_mail
   Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
   Net::POP3.start(@config['pop_host'], @config['pop_port'], @config['user_name'], @config['user_passwd']) do |pop|
      if pop.mails.empty?
         puts("-- no mail.")
      else
         pop.each_mail do |m|
            puts("-- >>> processing new message ...")
	    msg = m.pop
	    # -- is the message one that we expect and know how to handle ?
            if !/==.*==/.match(msg)
               do_reply("-- ERROR: wrong argument supplied !", mail_help)
	    else
	       # -- ok, this message is for us
	       msg = /^(.*)(==.*==).*$/.match(msg)[2].gsub(/==/, '').strip
	       case msg
                  when /help/
                     do_reply("-- Help on using mail interface delivered !", mail_help)
                  when /list/
                     xxx = `rake print_human`
                     do_reply("-- list of objects delivered !", xxx)
                  when /play\s+.*$/
	             keyword = msg.gsub(/play/, '').strip
		     # -- do we have two-step-authentication enabled ?
		     if @config['two_step_authentication']
		        authentication_send_code(keyword)
		     else
		        play_request(keyword)
	             end
                  when /authentication:\s+.*$/
	             code = msg.gsub(/authentication:/, '').strip
		     authentication_process_code(code)
	       end
	    end
            m.delete
            puts "-- >>> done ..."
         end
      end
   end
end

# -- start mail gateway
desc "-- start mail gateway..."
task :mail_gateway do
   pop_mail
end

# -- END EMAIL GATEWAY RELATED CODE

# -- print tests
desc "-- print tests..."
task :print_human do
   Rake::Task["find_all"].invoke
   @tests.each { |t|
      # -- only print it if it is not in the exclude list
      if !@config['exclude_list'].include?(t.execute_class)
         begin
            puts t.to_s
         rescue => e
            puts "-- ERROR: " + e.inspect
            puts "   (in test: #{t.execute_class})"
         end
      end
   }
end

# -- run all tests
desc "-- run all tests..."
task :run do
   prepare_reports_dir
   Rake::Task["find_all"].invoke
   MainClass.new(@tests, @config).normal_run
end

# -- DRB related
desc "-- start DRB service"
task :drb do
   prepare_reports_dir
   Rake::Task["find_all"].invoke
   MainClass.new(@tests, @config).start_drb
end

# -- main class
class MainClass
   include DRbUndumped
   attr_accessor :tests, :config, :execution_time, :tests_retried_counter, :exit_status, :t_start, :t_finish

   def initialize(tests, config)
      @tests                 = tests
      @config                = config
      @execution_time        = 0
      @tests_retried_counter = 0
      @exit_status           = 0
      @mutex                 = Mutex.new
   end

   def start_drb
      DRb.start_service('druby://localhost:9000', self)
      puts("-- drb service started on: " + DRb.uri)
      @t_start = Time.now
      sleep 3
      run_in_parallel
      DRb.thread.join # Don't exit just yet!
   end

   def run_in_parallel
      batch = Array.new
      index = 0
      @tests.each { |t|
	 if index == @config['batch_size']
	    index = 0
	    execute_batch(batch)
	    batch.clear
	    sleep @config['between_batch_wait_time']
	 end
         index += 1
	 batch << t
      }
      # -- execute leftover batch
      execute_batch(batch)
   end

   def execute_batch(batch)
      batch.each { |t|
	 sleep 1
         puts("-- starting: " + t.execute_class)
         fork { `ruby drb/drb_client.rb #{t.execute_class}` }
      }
   end

   def stop_drb
      sleep 1
      @t_finish = Time.now
      @execution_time = @t_finish - @t_start
      DRb.stop_service
      print_summary
      publish_stats
      clean_exit
   end

   def p(s)
      @mutex.synchronize do
         puts s
      end
   end

   def pprint(s)
      @mutex.synchronize do
         print s
      end
   end

   def inc_tests_retried_counter
      @mutex.synchronize do
         @tests_retried_counter += 1
      end
   end

   # -- normal run
   def normal_run
      tStart = Time.now
      # -- let's run each test now
      @tests.each { |t|
         begin
            t.validate
            # -- do we run test more than once if it failed first time ?
            if (t.exit_status == @config['test_exit_message_failed']) and (@config['test_retry'] > 0)
               puts("-- first attempt failed, will try again for a total of {#{@config['test_retry']}} number of times...")
	       retried_counter = 0
	       #@tests_retried_counter += 1
	       inc_tests_retried_counter
	       while(retried_counter < @config['test_retry'])
	          puts("-- {#{@config['test_retry'] - retried_counter}} number of attempts left...")
                  retried_counter += 1
                  t.validate
	          retried_counter = @config['test_retry'] if t.exit_status == @config['test_exit_message_passed']
	       end
            end
         rescue => e
            puts "-- ERROR: " + e.inspect
            puts "   (in test: #{t.execute_class})"
         end
      }
      tFinish = Time.now
      @execution_time = tFinish - tStart
      print_summary
      publish_stats
      clean_exit
   end

   # -- total by exit status
   def all_by_exit_status(status)
      a = Array.new
      @tests.each { |t|
         a << t if t.exit_status == status
      }
      return a
   end

   # -- what do we do on exit ?
   def print_summary
      passed   = all_by_exit_status(@config['test_exit_message_passed'])
      failed   = all_by_exit_status(@config['test_exit_message_failed'])
      skipped  = all_by_exit_status(@config['test_exit_message_skipped'])
      executed = passed.length + failed.length
      total    = passed.length + failed.length + skipped.length
      @config.merge!({'execution_time' => @execution_time, 'passed' => passed, 'failed' => failed, 'skipped' => skipped})
      Publisher.new(@config).publish_reports
      puts("\n==> DONE\n\n")
      puts("      -- execution time  : #{@execution_time.to_s} secs\n")
      puts("      -- reports prepared: #{@config['reports_dir']}\n")
      puts("      -- tests total     : #{total.to_s}\n")
      puts("      -- tests executed  : #{executed.to_s}\n")
      puts("      -- tests passed    : #{passed.length.to_s}\n")
      puts("      -- tests failed    : #{failed.length.to_s}\n")
      puts("      -- tests skipped   : #{skipped.length.to_s}\n")
      if (@config['test_retry'] > 0)
         puts("      -- tests re-tried  : #{@tests_retried_counter.to_s}\n")
      end
      if failed.length > 0
         puts("\n\n==> STATUS: [ some tests failed - execution failed ]\n")
         @exit_status = 1
      end
   end

   # -- may need to publish some stats: only for passed tests
   def publish_stats
      if @config['publish_statistics']
         puts("\n\n-- publishing stats...")
	 session = GoogleSpreadsheet.login(@config['gs_credentials']['user'], @config['gs_credentials']['password'])
	 worksheet = session.spreadsheet_by_key(@config['gs_credentials']['key']).worksheets[0]
	 @tests.each { |t|
	    if @config['statistics_test_list'].include?(t.execute_class) and t.exit_status == @config['test_exit_message_passed']
	       puts("       => " + t.execute_class)
	       row = worksheet.num_rows + 1 # -- should point to the first empty row
	       worksheet[row, 1] = t.execute_class
	       worksheet[row, 2] = t.execution_time.to_i.to_s
	       worksheet[row, 3] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
	    end
	 }
	 worksheet.save
	 puts("\n-- Done.\n\n")
      end
   end

   # -- clean exit
   def clean_exit
      exit(@exit_status)
   end
end

#
# ::: Publisher [ creating report files ] :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
class Publisher
   def initialize(config)
      @config = config
      @total     = @config['passed'].length + @config['failed'].length + @config['skipped'].length
   end

   def write_file(file, data)
      File.open(file, 'w') {|f| f.write(data) }
   end

   def create_html_reports(status)
      output  = "<html><body>\n\nTests that #{status}:<br><br><table><tr><td>test</td><td>time</td></tr><tr></tr>\n"
      @config[status].each { |t|
         output += "<tr><td><a href='#{t.execute_class}.html'>#{t.execute_class}</a></td><td>#{t.execution_time}</td></tr>\n"
      }
      output += "</table></body></html>"
      write_file(@config['reports_dir'] + "/#{status}.html", output)
   end

   def publish_reports
      # -- remove reports dir if it exists, then create it
      # -- create an xml file
      document  = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
      document += "<testsuites>\n"
      document += "   <testsuite successes='#{@config['passed'].length}'"
      document += "   skipped='#{@config['skipped'].length}' failures='#{@config['failed'].length}'"
      document += "   time='#{@config['execution_time']}' name='FunctionalTestSuite' tests='#{@total}'>\n"
      if @config['passed'].length > 0
         @config['passed'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@config['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <passed message='Test Passed'><![CDATA[\n\n#{t.output}\n\n]]>\n       </passed>\n"
            document += "   </testcase>\n"
         }
      end
      if @config['failed'].length > 0
         @config['failed'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@config['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <error message='Test Failed'><![CDATA[\n\n#{t.output}\n\n]]>\n       </error>\n"
            document += "   </testcase>\n"
         }
      end
      if @config['skipped'].length > 0
         @config['skipped'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@config['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <skipped message='Test Skipped'><![CDATA[\n\n#{t.output}\n\n]]>\n       </skipped>\n"
            document += "   </testcase>\n"
         }
      end
      document += "   </testsuite>\n"
      document += "</testsuites>\n"
      # -- remove any occurences of '&&' (like in possible output of javascript functions)
      document.gsub!(/&&/,'')
      # -- write XML report
      write_file(@config['reports_dir'] + "/" + @config['xml_report_file_name'], document)
      # -- write HTML report
      totals  = "<html><body>\n\nTotal tests: #{@total.to_s}<br>\n"
      totals += "Passed: <a href='passed.html'>#{@config['passed'].length.to_s}</a><br>\n"
      totals += "Failed: <a href='failed.html'>#{@config['failed'].length.to_s}</a><br>\n"
      totals += "Skipped: <a href='skipped.html'>#{@config['skipped'].length.to_s}</a><br>\n"
      totals += "Execution time: #{@config['execution_time']}<br>\n</body></html>"
      write_file(@config['reports_dir'] + "/report.html", totals)
      # -- create individual html report files complete with test output
      create_html_reports("passed")
      create_html_reports("failed")
      create_html_reports("skipped")
   end
end

#
# ::: Test class [ running a test ] :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
class Test
    include DRbUndumped
    attr_accessor :path, :execute_class, :execute_args, :keywords, :description, :author,
                  :exit_status, :output, :execution_time, :config, :timeout
    def initialize(hash, config)
       @exit_status    = @output = @path = @execute_class = @execute_args = @keywords = @description = @author = ""
       @config         = config
       @execution_time = 0.0
       @timeout        = @config['test_timeout']
       @path           = hash['path']
       @execute_class  = hash['execute_class']
       @execute_args   = hash['execute_args']
       @keywords       = hash['keywords']
       @description    = hash['description']
       @author         = hash['author']
       @cmd            = @execute_class
    end

    # -- we should do something useful here
    def is_valid
       return false if @config['exclude_list'].include?(@execute_class)
       return true
    end

    def validate
       if is_valid
          # -- run the test if its valid
          run
          # -- write entire test output into its own log file
          write_log
       else
          # -- skipping this test
          @exit_status = @config['test_exit_message_skipped']
       end
    end

    def write_file(file, data)
       File.open(file, 'w') {|f| f.write(data) }
    end

    def write_log
       d = /^(.*\/).*/.match(@execute_class)[1]
       FileUtils.mkdir_p(@config['reports_dir'] + "/#{d}")
       file = @config['reports_dir'] + "/#{@execute_class}.html"
       # -- append a date_time if file already exist
       if File.exist?(file)
	  t      = Time.now
  	  suffix = t.year.to_s + t.month.to_s.rjust(2,"0") + t.day.to_s.rjust(2,"0") + t.hour.to_s + t.min.to_s + t.sec.to_s
	  file   = @config['reports_dir'] + "/" + @execute_class + "_" + suffix + '.html'
       end
       write_file(file, "<html><body><pre>" + @output + "</pre></body></html>")
    end

    def run
       @cmd = @cmd + " " + @execute_args unless @execute_args == ""
       tStart = Time.now
       print("-- #{tStart.strftime('[%H:%M:%S]')} running: [#{@cmd}] ")
       begin
          status = Timeout::timeout(@timeout.to_i) {
             @output      = `#{@config['interpreter']} #{@cmd} 2>&1`
             @exit_status = case @output
                when /#{@config['test_exit_message_passed']}/ then @config['test_exit_message_passed']
                when /#{@config['test_exit_message_failed']}/ then @config['test_exit_message_failed']
                else @config['test_exit_message_failed']
             end
          }
       rescue Timeout::Error => e
          @output << "\n\n[ TERMINATED WITH TIMEOUT (#{@timeout.to_s}) ]"
          @exit_status = @config['test_exit_message_failed']
       ensure
          puts @exit_status
          puts @output if @config['output_on']
       end
       tFinish = Time.now
       @execution_time = tFinish - tStart
    end

    def to_s
        s = "\n  path:          " + @path              + "\n"
        if @author != nil
           s += "  author         " + @author              + "\n"
        end
        s += "  execute_class  " + @execute_class       + "\n"
        s += "  execute_args   " + @execute_args        + "\n"
        s += "  keywords       " + @keywords.join(',')  + "\n"
        s += "  description    " + @description         + "\n"
        s += "  exit_status    " + @exit_status.to_s    + "\n"
        s += "  output         " + @output              + "\n"
        s += "  execution_time " + @execution_time.to_s + "\n\n"
        return s
    end
end
