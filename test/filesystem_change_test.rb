require File.expand_path('../test_helper', __FILE__)

describe "Kicker, when a change occurs" do
  before do
    remove_tmp_files!
    
    Kicker.any_instance.stubs(:last_command_succeeded?).returns(true)
    Kicker.any_instance.stubs(:log)
    @kicker = Kicker.new
  end
  
  it "should store the current time as when the last change occurred" do
    now = Time.now
    Time.stubs(:now).returns(now)
    
    @kicker.send(:finished_processing!)
    @kicker.last_event_processed_at.should.be now
  end
  
  it "should return an array of files that have changed since the last event" do
    file1 = touch('1')
    file2 = touch('2')
    file3 = touch('3')
    file4 = touch('4')
    @kicker.send(:finished_processing!)
    
    events = [event(file1, file2), event(file3, file4)]
    
    @kicker.send(:changed_files, events).should == []
    @kicker.send(:finished_processing!)
    
    sleep(1)
    touch('2')
    
    @kicker.send(:changed_files, events).should == [file2]
    @kicker.send(:finished_processing!)
    
    sleep(1)
    touch('1')
    touch('3')
    
    @kicker.send(:changed_files, events).should == [file1, file3]
  end
  
  it "should return an empty array when a directory doesn't exist while collecting the files in it" do
    @kicker.send(:files_in_directory, '/does/not/exist').should == []
  end
  
  it "should not break when determining changed files from events with missing files" do
    file1 = touch('1')
    file2 = touch('2')
    @kicker.send(:finished_processing!)
    sleep(1)
    touch('2')
    
    events = [event(file1, file2), event('/does/not/exist')]
    @kicker.send(:changed_files, events).should == [file2]
  end
  
  it "should return relative file paths if the path is relative to the current work dir" do
    sleep(1)
    file = touch('1')
    
    Dir.stubs(:pwd).returns('/tmp')
    @kicker.send(:changed_files, [event(file)]).should == [File.basename(file)]
  end
  
  it "should call the full_chain with all changed files" do
    files = %w{ /file/1 /file/2 }
    events = [event('/file/1'), event('/file/2')]
    
    @kicker.expects(:changed_files).with(events).returns(files)
    @kicker.full_chain.expects(:call).with(files)
    @kicker.expects(:finished_processing!)
    
    @kicker.send(:process, events)
  end
  
  it "should not call the full_chain if there were no changed files" do
    @kicker.stubs(:changed_files).returns([])
    @kicker.full_chain.expects(:call).never
    @kicker.expects(:finished_processing!).never
    
    @kicker.send(:process, [event()])
  end
  
  private
  
  def touch(file)
    file = "/tmp/kicker_test_tmp_#{file}"
    `touch #{file}`
    file
  end
  
  def event(*files)
    event = stub('FSEvent')
    event.stubs(:path).returns('/tmp')
    event
  end
  
  def remove_tmp_files!
    Dir.glob("/tmp/kicker_test_tmp_*").each { |f| File.delete(f) }
  end
end
