module ActiveScaffold::Actions
  module BatchDestroy

    def self.included(base)
      base.send :include, ActiveScaffold::Actions::BatchBase unless base < ActiveScaffold::Actions::BatchBase
      base.before_filter :batch_destroy_authorized_filter, :only => [:batch_destroy]
    end

    def batch_destroy
      batch_action
    end
    
    protected

    def before_do_batch_destroy
    end

    def batch_destroy_listed
      case active_scaffold_config.batch_destroy.process_mode
      when :delete then
        each_record_in_scope do |record|
          destroy_record(record) if authorized_for_job?(record)
        end
      when :delete_all then
        do_search if respond_to? :do_search
        # dummy condition cause we have to call delete_all on relation not on association
        beginning_of_chain.where('1=1').delete_all(all_conditions)
      else
        Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_destroy.process_mode} for action batch_destroy")
      end
      
    end

    def batch_destroy_marked
      case active_scaffold_config.batch_destroy.process_mode
      when :delete then
        each_marked_record do |record|
          destroy_record(record) if authorized_for_job?(record)
        end
      when :delete_all then
        active_scaffold_config.model.where(active_scaffold_config.model.primary_key => marked_records.to_a).delete_all
        do_demark_all
      else
        Rails.logger.error("Unknown process_mode: #{active_scaffold_config.batch_destroy.process_mode} for action batch_destroy")
      end
    end

    def destroy_record(record)
      @successful = nil
      @record = record

      do_destroy
      if successful?
        @record.as_marked = false if batch_scope == 'MARKED'
      else
        error_records << @record
      end
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def batch_destroy_authorized?(record = nil)
      authorized_for?(:crud_type => :delete)
    end

    def batch_destroy_marked_ignore?(record = nil)
      !active_scaffold_config.actions.include? :mark
    end

    private

    def batch_destroy_authorized_filter
      link = active_scaffold_config.batch_destroy.link || active_scaffold_config.batch_destroy.class.link
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.first.security_method)
    end
  end
end
