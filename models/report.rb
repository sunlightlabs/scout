class Report
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :status
  field :source
  field :message
  field :attached, :type => Hash, :default => {}
  
  index :status
  index :source
  index :created_at
  
  def self.file(status, source, message, attached = {})
    report = Report.create!(:source => source.to_s, :status => status, :message => message, :attached => attached)
    puts "\n#{report}"
    report
  end
  
  def self.failure(source, message, objects = {})
    file 'FAILURE', source, message, objects
  end
  
  def self.warning(source, message, objects = {})
    file 'WARNING', source, message, objects
  end
  
  def self.success(source, message, objects = {})
    file 'SUCCESS', source, message, objects
  end

  def self.exception(source, message, exception)
    file 'FAILURE', source, message, {
      'exception' => {
        'backtrace' => exception.backtrace, 
        'message' => exception.message, 
        'type' => exception.class.to_s
    }}
  end
  
  def to_s
    msg = "[#{status}] #{source}\n#{message}"
    if self[:exception]
      msg += "\n\t#{self[:exception]['type']}: #{self[:exception]['message']}"
      if self[:exception]['backtrace'] and self[:exception]['backtrace'].respond_to?(:each)
        self[:exception]['backtrace'].first(5).each {|line| msg += "\n\t\t#{line}"}
      end
    end
    msg
  end
  
  def to_minutes(seconds)
    min = seconds / 60
    sec = seconds % 60
    "#{min > 0 ? "#{min}m," : ""}#{sec}s"
  end
end