module DeviseInvitable::Controllers::Registrations
  def self.included(controller)
    controller.send :around_filter, :keep_invitation_info, :only => :create
  end

  protected

  def destroy_if_previously_invited
    hash = params[resource_name]
    if hash && hash[:email]
      conditions = {:email => hash[:email], :encrypted_password => ''}
      if(resource_class.respond_to?(:where)) # ActiveRecord, Mongoid
        resource = resource_class.where(conditions).first
      else
        resource = resource_class.first(conditions)
      end
      if resource
        @invitation_info = Hash[resource.invitation_fields.map {|field|
          [field, resource.send(field)]
        }]
        resource.destroy
      end
    end
  end

  def keep_invitation_info
    resource_invitable = resource_class.devise_modules.include?(:invitable)
    destroy_if_previously_invited if resource_invitable
    yield
    reset_invitation_info if resource_invitable
  end

  def reset_invitation_info
    # Restore info about the last invitation (for later reference)
    # Reset the invitation_info only, if invited_by_id is still nil at this stage:
    
    conditions = {:email => params[resource_name][:email], :invited_by_id => nil}
    if(resource_class.respond_to?(:where)) # ActiveRecord, Mongoid
      resource = resource_class.where(conditions).first
    else
      resource = resource_class.first(conditions)
    end
    if resource && @invitation_info
      resource.invitation_fields.each do |field|
        resource.send("#{field}=", @invitation_info[field])
      end
      resource.save!
    end
  end
end
