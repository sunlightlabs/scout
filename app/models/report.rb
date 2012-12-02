class Report
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :status
  field :source
  field :message
  field :elapsed_time, type: Float
  field :attached, type: Hash, :default => {}
  
  index status: 1
  index source: 1
  index created_at: 1
  
  def self.file(status, source, message, attached = {})
    report = Report.create!(source: source.to_s, status: status, message: message, attached: attached)
    # stdout, but don't bother stdout-ing reports COMPLETE reports, or reports that will be emailed
    puts "\n#{report}" unless Sinatra::Application.test? or ['FAILURE', 'WARNING', 'COMPLETE'].include?(status)
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

  def self.complete(source, message, objects = {})
    file 'COMPLETE', source, message, objects
  end

  def self.exception(source, message, exception, objects = {})
    file 'FAILURE', source, message, {
      'exception' => exception_to_hash(exception)
      }.merge(objects)
  end
  
  def to_s
    "[#{status}] #{source} | #{message}"
  end

  def self.exception_to_hash(exception)
    {
      'backtrace' => exception.backtrace,
      'message' => exception.message,
      'type' => exception.class.to_s
    }
  end
end