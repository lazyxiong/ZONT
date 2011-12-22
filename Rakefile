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

require 'net/pop'
require 'net/smtp'
require 'tlsmail'
require "timeout"
require "fileutils"
require "yaml"

# -- global vars
task :default => [:run]
@suite_root            = File.expand_path "#{File.dirname(__FILE__)}"
@rake_env_file         = "#{@suite_root}/rake.env.yaml"
@rake_env_user_file    = "#{@suite_root}/user.rake.env.yaml"
@tests                 = []
@tests_retried_counter = 0
@executed_tests        = 0
@reports_dir           = ENV['HOME'] + "/rake_reports" # -- default
@reports_dir           = ENV['REPORTS_DIR'] if ENV['REPORTS_DIR'] != nil
#
# -- the following vars control the behavior of running tests: default values
@test_data = {
   'output_on'                 => false,
   'test_retry'                => false,
   'test_exit_message_passed'  => "PASSED",
   'test_exit_message_failed'  => "FAILED",
   'test_exit_message_skipped' => "SKIPPED",
   'xml_report_class_name'     => "qa.tests",
   'xml_report_file_name'      => "TESTS-TestSuites.xml",
   'interpreter'               => "ruby",
   'test_extension'            => ".rb",
   'excludes'                  => ".svn",
   'test_dir'                  => "tests",
   # -- mail related vars
   'pop_host'                  => "pop.gmail.com",
   'pop_port'                  => 995,
   'smtp_host'                 => "smtp.gmail.com",
   'smtp_port'                 => 587,
   'mail_domain'               => "gmail.com",
   'user_name'                 => "",
   'user_passwd'               => "",
   'reply_email'               => ""
}

#    *************************** BEGIN SETUP ***************************

# -- write out test data hash into a YAML file to hold basic ZONT environment
def write(filename, hash)
   File.open(filename, "w") { |f| f.write(hash.to_yaml) }
end

# -- if 'rake.env.yaml' exists, load values from there into @test_data hash; otherwise write defaults to newly created 'rake.env.yaml' file.
if File.exist?(@rake_env_file)
   @test_data.merge!(YAML::load(File.read(@rake_env_file)))
else
   puts "\n\n-- INFO: {#{@rake_env_file}}  doesn't exist, it will be created with default values.\n\n"
   write(@rake_env_file, @test_data)
end
# -- loading user-defined properties from yaml: if 'user.rake.env.yaml' file exists, we'll use it to overwrite @test_data hash
if File.exist?(@rake_env_user_file)
   YAML::load(File.read(@rake_env_user_file)).each_pair { |key, value|
      @test_data[key] = value if @test_data[key] != nil
   }
end
# -- merge any other variables that we don't want to be stored in the 'rake.env' file into @test_data hash
@test_data.merge!({'reports_dir' => @reports_dir})

#    *************************** END SETUP ***************************

# -- usage
desc "-- usage"
task :help do
    puts "\n-- usage: \n\n"
    puts "   rake help                                     : print this message"
    puts "   rake                                          : this will by default run :run task, which runs all tests"
    puts "   rake run KEYWORDS=<keyword1,keyword2>         : this will run tests based on keyword"
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
   FileUtils.rm_r(@test_data['reports_dir']) if File.directory?(@test_data['reports_dir'])
   FileUtils.mkdir_p(@test_data['reports_dir'])
end

# -- our own each method yielding each test in the @tests array
def each
   @tests.each { |t| yield t }
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
   @tests << Test.new(data, @test_data) if data['keywords'] != nil and data['keywords'] != ""
end

# -- find tests and load them one by one, applying keyword-filter at the end
desc "-- find all tests..."
task :find_all do
   FileList["#{@test_data['test_dir']}/**/*[T|t]est#{@test_data['test_extension']}"].exclude(@test_data['excludes']).each { |tc_name|
      load_test(tc_name)
   }
   filter_by_keywords
end

# -- do_reply
def do_reply(subject, msg)
   full_msg=<<END_OF_MESSAGE
From: #{@test_data['user_name']}
To: #{@test_data['reply_email']}
Subject: #{subject}
Date: #{Time.now}

#{msg}
END_OF_MESSAGE
   Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
   Net::SMTP.start(@test_data['smtp_host'], @test_data['smtp_port'], @test_data['mail_domain'], @test_data['user_name'], @test_data['user_passwd'], :login) { |smtp|
      smtp.send_message(full_msg, @test_data['user_name'], @test_data['reply_email'])
   }
end

# -- pop mail
def pop_mail
   Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
   Net::POP3.start(@test_data['pop_host'], @test_data['pop_port'], @test_data['user_name'], @test_data['user_passwd']) do |pop|
      if pop.mails.empty?
         puts("-- no mail.")
      else
         pop.each_mail do |m|
            puts("-- >>> processing new message ...")
	    msg = m.pop
            if !/==.*==/.match(msg)
               do_reply("-- ERROR: wrong argument supplied !", mail_help)
	    else
	       msg = /^.*(==.*==).*$/.match(msg)[0].gsub(/==/, '').strip
	       case msg
                  when /help/
                     do_reply("-- Help on using mail interface delivered !", mail_help)
                  when /list/
                     xxx = `rake print_human`
                     do_reply("-- list of objects delivered !", xxx)
                  when /play\s+.*$/
	             keyword = msg.gsub(/play/, '').strip
                     xxx  = "-- executing: rake KEYWORD='" + keyword + "'\n\n"
		     xxx += `rake KEYWORD='#{keyword}'`
                     do_reply("-- status of playback delivered", xxx)
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

# -- print tests
desc "-- print tests..."
task :print_human do
   Rake::Task["find_all"].invoke
   each { |t|
      begin
         puts t.to_s
      rescue => e
         puts "-- ERROR: " + e.inspect
         puts "   (in test: #{t.execute_class})"
      end
   }
end

# -- run all tests
desc "-- run all tests..."
task :run do
   # -- first, let's setup/cleanup reports_dir
   prepare_reports_dir
   # -- now, find all tests
   Rake::Task["find_all"].invoke
   tStart = Time.now
   # -- let's run each test now
   each { |t|
      begin
         t.validate
         # -- do we run test more than once if it failed first time ?
         if (t.exit_status == @test_data['test_exit_message_failed']) and (@test_data['test_retry'])
            puts("-- first attempt failed, will try again...")
            t.validate
            @tests_retried_counter += 1
         end
      rescue => e
         puts "-- ERROR: " + e.inspect
         puts "   (in test: #{t.execute_class})"
      ensure
         @executed_tests += 1
      end
   }
   tFinish = Time.now
   @execution_time = tFinish - tStart
   clean_exit
end

# -- total by exit status
def all_by_exit_status(status)
   a = Array.new
   each { |t|
      a << t if t.exit_status == status
   }
   return a
end

# -- what do we do on exit ?
def clean_exit
   passed  = all_by_exit_status(@test_data['test_exit_message_passed'])
   failed  = all_by_exit_status(@test_data['test_exit_message_failed'])
   skipped = all_by_exit_status(@test_data['test_exit_message_skipped'])
   @test_data.merge!({'execution_time' => @execution_time, 'passed' => passed, 'failed' => failed, 'skipped' => skipped})
   Publisher.new(@test_data).publish_reports
   puts("\n==> DONE\n\n")
   puts("      -- execution time  : #{@execution_time.to_s} secs\n")
   puts("      -- tests executed  : #{@executed_tests.to_s}\n")
   puts("      -- reports prepared: #{@test_data['reports_dir']}\n")
   puts("      -- tests passed    : #{passed.length.to_s}\n")
   puts("      -- tests failed    : #{failed.length.to_s}\n")
   puts("      -- tests skipped   : #{skipped.length.to_s}\n")
   if @test_data['test_retry']
      puts("      -- tests re-tried  : #{@tests_retried_counter.to_s}\n")
   end
   if failed.length > 0
      puts("\n\n==> STATUS: [ some tests failed - execution failed ]\n")
      exit(1)
   end
   exit(0)
end

#
# ::: Publisher [ creating report files ] :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
class Publisher
   def initialize(test_data)
      @test_data = test_data
      @total     = @test_data['passed'].length + @test_data['failed'].length + @test_data['skipped'].length
   end

   def write_file(file, data)
      File.open(file, 'w') {|f| f.write(data) }
   end

   def create_html_reports(status)
      output  = "<html><body>\n\nTests that #{status}:<br><br><table><tr><td>test</td><td>time</td></tr><tr></tr>\n"
      @test_data[status].each { |t|
         output += "<tr><td><a href='#{t.execute_class}.html'>#{t.execute_class}</a></td><td>#{t.execution_time}</td></tr>\n"
      }
      output += "</table></body></html>"
      write_file(@test_data['reports_dir'] + "/#{status}.html", output)
   end

   def publish_reports
      # -- remove reports dir if it exists, then create it
      # -- create an xml file
      document  = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
      document += "<testsuites>\n"
      document += "   <testsuite successes='#{@test_data['passed'].length}'"
      document += "   skipped='#{@test_data['skipped'].length}' failures='#{@test_data['failed'].length}'"
      document += "   time='#{@test_data['execution_time']}' name='FunctionalTestSuite' tests='#{@total}'>\n"
      if @test_data['passed'].length > 0
         @test_data['passed'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@test_data['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <passed message='Test Passed'><![CDATA[\n\n#{t.output}\n\n]]>\n       </passed>\n"
            document += "   </testcase>\n"
         }
      end
      if @test_data['failed'].length > 0
         @test_data['failed'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@test_data['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <error message='Test Failed'><![CDATA[\n\n#{t.output}\n\n]]>\n       </error>\n"
            document += "   </testcase>\n"
         }
      end
      if @test_data['skipped'].length > 0
         @test_data['skipped'].each  { |t|
            document += "   <testcase name='#{t.execute_class}' classname='#{@test_data['xml_report_class_name']}' time='#{t.execution_time}'>\n"
            document += "      <skipped message='Test Skipped'><![CDATA[\n\n#{t.output}\n\n]]>\n       </skipped>\n"
            document += "   </testcase>\n"
         }
      end
      document += "   </testsuite>\n"
      document += "</testsuites>\n"
      # -- write XML report
      write_file(@test_data['reports_dir'] + "/" + @test_data['xml_report_file_name'], document)
      # -- write HTML report
      totals  = "<html><body>\n\nTotal tests: #{@total.to_s}<br>\n"
      totals += "Passed: <a href='passed.html'>#{@test_data['passed'].length.to_s}</a><br>\n"
      totals += "Failed: <a href='failed.html'>#{@test_data['failed'].length.to_s}</a><br>\n"
      totals += "Skipped: <a href='skipped.html'>#{@test_data['skipped'].length.to_s}</a><br>\n"
      totals += "Execution time: #{@test_data['execution_time']}<br>\n</body></html>"
      write_file(@test_data['reports_dir'] + "/report.html", totals)
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
    attr_accessor :path, :execute_class, :execute_args, :keywords, :description, :author,
                  :exit_status, :output, :execution_time, :test_data
    def initialize(hash, test_data)
       @exit_status    = @output = @path = @execute_class = @execute_args = @keywords = @description = @author = ""
       @test_data      = test_data
       @execution_time = 0.0
       @timeout        = 1200 # miliseconds
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
          @exit_status = @test_data['test_exit_message_skipped']
       end
    end

    def write_file(file, data)
       File.open(file, 'w') {|f| f.write(data) }
    end

    def write_log
       d = /^(.*\/).*/.match(@execute_class)[1]
       FileUtils.mkdir_p(@test_data['reports_dir'] + "/#{d}")
       write_file(@test_data['reports_dir'] + "/#{@execute_class}.html", "<html><body><pre>" + @output + "</pre></body></html>")
    end

    def run
       @cmd = @cmd + " " + @execute_args unless @execute_args == ""
       ENV["REPORT_FILE"] = File.join(@test_data['reports_dir'], @execute_class)
       tStart = Time.now
       print("-- #{tStart.strftime('[%H:%M:%S]')} running: [#{@cmd}] ")
       begin
          status = Timeout::timeout(@timeout.to_i) {
             @output      = `#{@test_data['interpreter']} #{@cmd} 2>&1`
             @exit_status = case @output
                when /#{@test_data['test_exit_message_passed']}/ then @test_data['test_exit_message_passed']
                when /#{@test_data['test_exit_message_failed']}/ then @test_data['test_exit_message_failed']
                else @test_data['test_exit_message_failed']
             end
          }
       rescue Timeout::Error => e
          @output << "\n\n[ TERMINATED WITH TIMEOUT (#{@timeout.to_s}) ]"
          @exit_status = @test_data['test_exit_message_failed']
       ensure
          puts @exit_status
          puts @output if @test_data['output_on']
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
