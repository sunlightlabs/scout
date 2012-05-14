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
    # stdout, but don't bother stdout-ing reports that will be emailed
    puts "\n#{report}" unless ['FAILURE', 'WARNING'].include?(status)
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

  def self.exception(source, message, exception, objects = {})
    file 'FAILURE', source, message, {
      'exception' => {
        'backtrace' => exception.backtrace, 
        'message' => exception.message, 
        'type' => exception.class.to_s
    }.merge(objects)}
  end
  
  def to_s
    "[#{status}] #{source} | #{message}"
  end
  
  def to_minutes(seconds)
    min = seconds / 60
    sec = seconds % 60
    "#{min > 0 ? "#{min}m," : ""}#{sec}s"
  end
end