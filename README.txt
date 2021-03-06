
Crossover 
=======


Crossover (aka Xover) is a layer allowing to launch web application testing scripts of several type and gathering results in several ways.
It is written in Ruby.

At the time being, it allows to run:
- Jmeter  test plans (*.jmx)  (aka TestType="Jmeter" tests)
- Selenium IDE test plans (*.html) (aka TestType="SeleniumIDE" tests)
- Cucumber features

Watir-webdriver is used to executed Selenium IDE plans
If you use Jmeter, you have to install and configure it.
If you use Watir Webdriver, you have to install and configure it.
T   ested on Ruby 2.1.7
A single configuration file allows to configure all features, load plans etc.

Beside checking for correct execution of the plan, it check for correct timing.
Each plan can have a Warning time duration and a Fail duration.
You can also specify Warning and Fail thresholds for specific steps of the plan.

Crossover has very complete log tool integrated, which allows you to check the tests execution.
Also, in case of error a screenshot is taken.
HTML report is produced
You have to specify log path, and the log level.

Output
=====
Output can be produced in several way. 
Each output can be enabled independently of each other:
- you can send results to NSCA server for each test (Nagios environment)
- you can write results to .cmd file (useful in Nagios environment, in passive probe configuration)
- you can print a single line results on screen for each test 
- HTML table (one line per each service). Each day a new file is created and left behind. You can send it via email optionally.
- screen shots are taken (and left behind) where errors are detected.
- .jtl files are left behind for each plan and they are overwritten when executing the next test.
  When running in "standAlone" mode (see below) a "plan name"-tot.jtl file is produced, holding all the results.
  This file is never overwritten (always appended).

NB purge of older files is left up to the system manager  

Installation
============
You have to download:
- Ruby 2.1.7
You have to install the following GEMs 
gem install rubygems-update
gem install rubyzip
gem install rspec
gem install headless
gem install ffi
gem install open4
gem install os
gem install mail
gem install net-ssh
gem install cucumber
gem install watir-webdriver
gem install watir-webdriver-performance
gem install cucumber-formatter

If you plan to use it, you have to download & install Java & Jmeter:
- http://jmeter.apache.org/usermanual/get-started.html#install

 
How it works
============
At the beginning of the test, the config file is read, then is starts executing the plans one at a time.

You can select 4 different modes (aka runMode):
+ "Cucumber"	This is used when the library is called in a cucumber environment
+ "standAlone"	This is used to launch manually a cycling monitor. All tests are executed.
				You must specify:
				++	pollTime="2"		# minutes between polling
				++	testDuration="8"	# test total duration (minutes)
				This can be useful to launch a monitoring campaign, without having a monitor system involved.
+ "Plugin"		Not supported anymore (at this stage)
+ "passive"		Not supported anymore (at this stage)

For each plan a related .jtl file is produced.
This is native behaviour for Jmeter, while it is purposedly written for Watir webdriver.
At the end of execution, the .jtl file is parsed for errors and checked against time thresholds.

You can select the type of browser you want to use.
I tested with Firefox, Explorer, Chrome. Of course, they must be present on the test system.
* At this time, only local browser ha been tested. Distributed configuration will be tested shortly. *
The browser is created when starting the test, and destroyed at the end. So the same browser is used throughout the whole test. 
This is a huge advantage in terms of execution time.

About Firefox, I recommend installing the ESR version, with auto-upgrade disabled.
Also, with Firefox, you can select the profile you want to use. (Webdriver is the name you find in the reference config file).
This make the startup faster, and allows you to manually configure the user preferences.
If you select a profile, you have to create it manually.
If you do not select a profile, a temporary profile is created and it is destroyed at the end of the test.

Required directory structure
================
/home
    /project_name
         /cfg
         /features
            /support
                env.rb
         /report
             /runID_name
    /Xover
         /cfg
         /resource
         /src

How to launch it (cucumber mode)
================
(in windows)
cd \home\project_name
call cucumber ./features --tags @demo  -r ./features CONF=./Cfg/demo_conf_ch.yml RUNID=runID_name -f html --out ./report/runID_name/ccReport.html     


At this time the only other option is:
  -x enable headless mode (Linux only)