require File.expand_path('../test_helper', __FILE__)

describe "Kicker" do
  it "should return the default paths to watch" do
    Kicker.paths.should == %w{ . }
  end
end

describe "Kicker, when initializing" do
  before do
    @now = Time.now
    Time.stubs(:now).returns(@now)
    
    @kicker = Kicker.new(:paths => %w{ /some/dir a/relative/path })
  end
  
  it "should return the extended paths to watch" do
    @kicker.paths.should == ['/some/dir', File.expand_path('a/relative/path')]
  end
  
  it "should have assigned the current time to last_event_processed_at" do
    @kicker.last_event_processed_at.should == @now
  end
  
  it "should use the default paths if no paths were given" do
    Kicker.new({}).paths.should == [File.expand_path('.')]
  end
end

describe "Kicker, when starting" do
  before do
    @kicker = Kicker.new(:paths => %w{ /some/file.rb }, :command => 'ls -l')
    @kicker.stubs(:log)
    Rucola::FSEvents.stubs(:start_watching)
    OSX.stubs(:CFRunLoopRun)
  end
  
  xit "should show the usage banner and exit when there are no paths and a command" do
    @kicker.instance_variable_set("@paths", [])
    @kicker.stubs(:validate_paths_exist!)
    
    Kicker::OPTION_PARSER.stubs(:call).returns(mock('OptionParser', :help => 'help'))
    @kicker.expects(:puts).with("help")
    @kicker.expects(:exit)
    
    @kicker.start
  end
  
  it "should warn the user and exit if any of the given paths doesn't exist" do
    @kicker.expects(:puts).with("The given path `/some/file.rb' does not exist")
    @kicker.expects(:exit).with(1)
    
    @kicker.start
  end
  
  it "should start a FSEvents stream which watches all paths, but the dirnames of paths if they're files" do
    @kicker.stubs(:validate_options!)
    File.stubs(:directory?).with('/some/file.rb').returns(false)
    
    Rucola::FSEvents.expects(:start_watching).with('/some')
    @kicker.start
  end
  
  it "should start a FSEvents stream with a block which calls #process with any generated events" do
    @kicker.stubs(:validate_options!)
    
    Rucola::FSEvents.expects(:start_watching).yields(['event'])
    @kicker.expects(:process).with(['event'])
    
    @kicker.start
  end
  
  it "should setup a signal handler for `INT' which stops the FSEvents stream and exits" do
    @kicker.stubs(:validate_options!)
    
    watch_dog = stub('Rucola::FSEvents')
    Rucola::FSEvents.stubs(:start_watching).returns(watch_dog)
    
    @kicker.expects(:trap).with('INT').yields
    watch_dog.expects(:stop)
    @kicker.expects(:exit)
    
    @kicker.start
  end
  
  it "should start a CFRunLoop" do
    @kicker.stubs(:validate_options!)
    
    OSX.expects(:CFRunLoopRun)
    @kicker.start
  end
  
  it "should register with growl if growl should be used" do
    @kicker.stubs(:validate_options!)
    @kicker.use_growl = true
    
    Growl::Notifier.sharedInstance.expects(:register).with('Kicker', Kicker::GROWL_NOTIFICATIONS.values)
    @kicker.start
  end
  
  it "should _not_ register with growl if growl should not be used" do
    @kicker.stubs(:validate_options!)
    @kicker.use_growl = false
    
    Growl::Notifier.sharedInstance.expects(:register).never
    @kicker.start
  end
end