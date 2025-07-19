require "twilio.rb"
class MessagesController < ApplicationController
  before_action :set_message, only: %i[ show edit update destroy ]

skip_before_action :authenticate_user!, only: [:inbound_sms]
skip_before_action :verify_authenticity_token, only: [:inbound_sms]

  # GET /messages or /messages.json

  # GET /messages or /messages.json
  def index
    org_number = current_organization.twilio_number
    if params[:conversation_partner]
      @conversation_partner = params[:conversation_partner]
      @messages = current_organization.messages
        .where(
          "(sent_to = :org AND sent_from = :partner) OR (sent_from = :org AND sent_to = :partner)",
          org: org_number,
          partner: @conversation_partner
        )
        .order(:created_at)
    else
      org_number_escaped = ActiveRecord::Base.connection.quote(org_number)
      @message_threads = current_organization.messages
        .select("
          CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END AS conversation_partner,
          MAX(created_at) as latest_message_time,

          COUNT(*) as message_count,
          (SELECT body FROM messages m2 
           WHERE (m2.sent_to = #{org_number_escaped} AND m2.sent_from = CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END) 
              OR (m2.sent_from = #{org_number_escaped} AND m2.sent_to = CASE WHEN sent_to = #{org_number_escaped} THEN sent_from ELSE sent_to END)
           ORDER BY m2.created_at DESC LIMIT 1) as body
        ")
        .group("conversation_partner")
        .order("MAX(created_at) DESC")
    end
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

  def inbound_sms
    #TODO:
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