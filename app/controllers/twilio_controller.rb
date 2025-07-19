class TwilioController < ApplicationController
    # before_action :turn_off_304_not_modified
    skip_before_action :authenticate_user!, only: [:message_status_from_twilio]
    require 'twilio'

    # GET /twilio/get_available_twilio_phone_numbers_for_purchase?area_code=${areaCode} #responds as JSON
    def get_available_twilio_phone_numbers_for_purchase
        #Only handle JSON requests.
        #Paramaters need to include the area code:
        area_code = params[:area_code]
        available_phone_numbers = Twilio.find_available_phone_numbers(area_code)
        render :json => {:response => "Success", numbers: available_phone_numbers}, :status => 200
    end
    
      # POST /twilio/message_status_from_twilio
    # Twilio POSTs to this route in order to update us about the message status after we attempt to send it. 
    # This is so we can tell the user if a message was unsuccessful in sending.
    def message_status_from_twilio
      sid = params[:SmsSid]
      status = params[:SmsStatus]
      error = params[:ErrorCode] #TODO: Can we combine this into a different error message.?
      # error_message = ? #TODO: we should get the message status and try to read it.. 
      message = Message.find_by(twilio_sid: sid)
      message.update_columns(status: status, error_message: error)
      render json: message
    end

    # POST /twilio/purchase_twilio_phone_number
    def purchase_available_phone_number
      number_to_purchase = params[:number_to_purchase]

      #this should be a boolean
      test_purchase_number = !params[:test_number_to_purchase].nil? ? ActiveModel::Type::Boolean.new.cast(params[:test_number_to_purchase]) : nil
      hardcoded_test_number = "3853655596" #This is a static number that 

      if (test_purchase_number)
        Organization.where(twilio_number: hardcoded_test_number).update_all(twilio_number: nil) #Remove the hardcoded test number from all other businesses first, since it's being claimed by this one and we can't have two businesses with the same twilio number.
      end
      #remove special characters in order to adhere to databse phone number style convention
      cleaned_number_for_database = test_purchase_number ? hardcoded_test_number : number_to_purchase.tr('^0-9', '')
      number_to_purchase = test_purchase_number ? Twilio.internationalize(hardcoded_test_number) : Twilio.internationalize(number_to_purchase) #add the +1 to the phone number..
      was_successful = Twilio.purchase_available_phone_number(number_to_purchase, current_organization, test_purchase_number)
      
      if (was_successful)
        current_organization.update(twilio_number: cleaned_number_for_database)

        #Now that they've purchased a number, let's go and add all those demo messages and phone calls into the database.
        # current_organization.add_demo_messages
        # current_organization.add_demo_phonecalls
        render :json => {:response => "Success", number: cleaned_number_for_database}, :status => 200
      else
        render :json => {:response => "Couldn't Register Phone Number"}, :status => 422
      end
    end
end
  