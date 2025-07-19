require "twilio.rb"
class MessagesController < ApplicationController
  before_action :set_message, only: %i[ show edit update destroy ]

skip_before_action :authenticate_user!, only: [:inbound_sms]
skip_before_action :verify_authenticity_token, only: [:inbound_sms]

  # GET /messages or /messages.json

  # GET /messages or /messages.json
  def index
    # org_number = current_organization.twilio_number
    # if params[:conversation_partner]
    #   @conversation_partner = params[:conversation_partner]
    #   @messages = current_organization.messages
    #     .where(
    #       "(sent_to = :org AND sent_from = :partner) OR (sent_from = :org AND sent_to = :partner)",
    #       org: org_number,
    #       partner: @conversation_partner
    #     )
    #     .order(:created_at)
    # else
    #   org_number_escaped = ActiveRecord::Base.connection.quote(org_number)
    #   @message_threads = current_organization.messages
    #     .select("
    #       CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END AS conversation_partner,
    #       MAX(created_at) as latest_message_time,
    #       COUNT(*) as message_count,
    #       (SELECT body FROM messages m2 
    #        WHERE (m2.sent_to = #{org_number_escaped} AND m2.sent_from = CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END) 
    #           OR (m2.sent_from = #{org_number_escaped} AND m2.sent_to = CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END)
    #        ORDER BY m2.created_at DESC LIMIT 1) as body
    #     ")
    #     .group("conversation_partner")
    #     .order("MAX(created_at) DESC")
    # end
  end

  # GET /messages/1 or /messages/1.json
  def show
  end

  # GET /messages/new
  def new
    @message = current_organization.messages.new
  end

  # GET /messages/1/edit
  def edit
  end

  # POST /messages or /messages.json
  def create
    @message = Message.new(message_params)

    respond_to do |format|
      if @message.save
        format.html { redirect_to @message, notice: "Message was successfully created." }
        format.json { render :show, status: :created, location: @message }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /messages/1 or /messages/1.json
  def update
    respond_to do |format|
      if @message.update(message_params)
        format.html { redirect_to @message, notice: "Message was successfully updated." }
        format.json { render :show, status: :ok, location: @message }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /messages/1 or /messages/1.json
  def destroy
    @message.destroy!

    respond_to do |format|
      format.html { redirect_to messages_path, status: :see_other, notice: "Message was successfully destroyed." }
      format.json { head :no_content }
    end
  end


  # POST /inbound_sms
  def inbound_sms
    Rails.logger.info("Just received twilio sms message with params: #{params}")
    
    #Our authentication method for making sure it's actually Twilio sending a message
    if !Twilio.verify_account_sid(params[:AccountSid]) 
      #TODO: This is going to require some custom security measures since we're not authenticated properly.
      render json: {message: "Unauthenticated"}, status: :unauthorized
      Rails.logger.info("The message failed when verifying the twilio account sid, responding with unauthorized response")
      return
    end

    organization, destination_phone_number, number_that_inbound_sms_was_sent_from = Twilio.parse_incoming_request(params[:To], params[:From])
    if organization.nil? #organization not found
      render json: {message: "The phone number this message was sent to does not exist to any organization"}, status: :unprocessable_entity
      return
    end
    
    body = params['Body']

    #create but don't deliver (we've already gotten the message)
    organization.messages.create(sent_to: organization.twilio_number, sent_from: number_that_inbound_sms_was_sent_from, body: body)

    this_message_came_from_a_non_registered_person = true
    this_message_came_from_a_registered_user = false
    this_message_came_from_superadmin = false

    @api_token = Rails.application.message_verifier(:llamabot_ws).generate(
      { session_id: SecureRandom.uuid, user_id: organization.users.first.id}, #scope by the organization's user id.
      expires_in: 30.minutes)

    if (this_message_came_from_a_non_registered_person)
      # available_routes = LlamaBotRails::RouteHelper.formatted_routes_xml(LlamaBotRails.allowed_routes.to_a)
      
      #TODO: kick off LlamaBot to handle this message.
      agent_params = {
        message: body,
        thread_id: number_that_inbound_sms_was_sent_from,
        agent_name: "llamabot",
        sent_from: number_that_inbound_sms_was_sent_from,
        sent_to: organization.twilio_number,
        api_token: @api_token,
        agent_prompt: """
       You are Leonardo the Llama!
        """
      }

      all_responses = LlamaBotRails::LlamaBot.send_agent_message(agent_params).to_a
      Rails.logger.info("All responses from LlamaBot: #{all_responses}")

      # agent_response = all_responses.second["content"]
      # message = organization.messages.create(sent_to: number_that_inbound_sms_was_sent_from, sent_from: organization.twilio_number, body: agent_response)
      # message.deliver!
      # Rails.logger.info("Sent a message from Leonardo the Llama to #{number_that_inbound_sms_was_sent_from} with response: #{agent_response}")
      #TODO: We can send a message from here.
    end

    #This was a public person messaging into our system.. 
    Rails.logger.info("It was an inbound SMS from a public facing user.")
    # new_message = organization.messages.create(sent_to: destination_phone_number, sent_from: number_that_inbound_sms_was_sent_from, body: body)

    # TODO: Some sort of turbo/stimulus thing to update the front end?
    # new_message.action_cable_update_messages_view_and_attach_image( image_params )

    twiml = Twilio::TwiML::MessagingResponse.new
    render xml: twiml.to_xml
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_message
      @message = Message.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def message_params
      params.require(:message).permit(:body, :sent_to, :sent_from, :twilio_sid, :twilio_error_message, :organization_id)
    end
end