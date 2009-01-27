require 'rubygems'
require 'rake/clean'
require 'ftools'
require 'fileutils'
require 'rake/testtask'
gem 'ci_reporter'
require 'ci/reporter/rake/test_unit'
projects = ['watir', 'firewatir', 'commonwatir']
 
desc "Generate all the Watir gems"
task :gems do
  projects.each do |x|
    Dir.chdir(x) {puts `rake.bat gem`}
  end
  FileUtils.makedirs 'gems'
  gems = Dir['*/pkg/*.gem']
  gems.each {|gem| FileUtils.install gem, 'gems'}
end

desc "Clean all the projects"
task :clean_subprojects do
  projects.each do |x|
    Dir.chdir(x) {puts `rake.bat clean`}
  end
end

task :clean => [:clean_subprojects]
CLEAN << 'gems/*'

desc 'Run unit tests for IE'
Rake::TestTask.new :test_ie do |t|
  t.test_files = FileList['watir/unittests/core_tests.rb']
  t.verbose = true
end

desc 'Run unit tests for FireFox'
task :test_ff do
  load 'firewatir/unittests/mozilla_all_tests.rb' 
end

task :move_ci_reports do
  dir_arr = Dir["watir/test/reports/*.xml"]
  dir_arr.each { |e| File::move(e, ENV['CC_BUILD_ARTIFACTS']) }
  
  dir_arr = Dir[ENV['CC_BUILD_ARTIFACTS'] + '/*.xml']
  if dir_arr.length != 0
    File::copy("transform-results.xsl", ENV['CC_BUILD_ARTIFACTS'])
    dir_arr.each do |f|
      sContent = File.readlines(f, '\n')
      sContent.each do |line|
        line.sub!(/<\?xml version=\"1.0\" encoding=\"UTF-8\"\?>/, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet type=\"text\/xsl\" href=\"transform-results.xsl\"?>")
      end
      xmlFile = File.open(f, "w+")
      xmlFile.puts sContent
      xmlFile.close
    end
  end
end

task :move_ci_reports_ff do
  dir_arr = Dir["firewatir/test/reports/*.xml"]
  dir_arr.each { |e| File::move(e, ENV['CC_BUILD_ARTIFACTS']) }
  
  dir_arr = Dir[ENV['CC_BUILD_ARTIFACTS'] + '/*.xml']
  if dir_arr.length != 0
    File::copy("transform-results.xsl", ENV['CC_BUILD_ARTIFACTS'])
    dir_arr.each do |f|
      sContent = File.readlines(f, '\n')
      sContent.each do |line|
        line.sub!(/<\?xml version=\"1.0\" encoding=\"UTF-8\"\?>/, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet type=\"text\/xsl\" href=\"transform-results.xsl\"?>")
      end
      xmlFile = File.open(f, "w+")
      xmlFile.puts sContent
      xmlFile.close
    end
  end
end

task :cruise => ['ci:setup:testunit', :test_ie, :move_ci_reports]

task :cruise_ff => ['ci:setup:testunit', :test_ff, :move_ci_reports_ff]

desc 'Build the html for the website (wtr.rubyforge.org)'
task :website do
  Dir.chdir 'doc' do
    puts system('call webgen -V 1')
  end
end

desc 'Build and publish the html for the website at wtr.rubyforge.org'
task :publish_website => [:website] do
  user = 'bret' # userid on rubyforge
  puts system("call pscp -v -r doc\\output\\*.* #{user}@rubyforge.org:/var/www/gforge-projects/wtr")
end

desc 'Run tests for all browser'
task :test => [:test_ie, :test_ff]
